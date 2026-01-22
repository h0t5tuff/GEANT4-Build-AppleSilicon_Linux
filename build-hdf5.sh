#!/usr/bin/env bash
set -euo pipefail

# This script builds HDF5 1.x latest stable tag (pre-2.0.0).
#   1) clone/update HDF5 repo
#   2) checkout latest stable < 2.0.0 (i.e. 1.x stable tag)
#   3) build+install HDF5 (threadsafe ON, HL OFF, C++ OFF, tests OFF)
#   4) patch h5cc in-place to support -show (for CMake FindHDF5)
#   5) quick CMake find test (find_package(HDF5) + compile dummy)

# User-tunable knobs:
HDF5_WORKDIR="${HDF5_WORKDIR:-$HOME/HDF5}"
REPO_DIR="$HDF5_WORKDIR/hdf5"
THREADSAFE="${HDF5_ENABLE_THREADSAFE:-ON}"
MAKE_JOBS="${MAKE_JOBS:-$(sysctl -n hw.ncpu)}"

# Prefer Ninja if installed, else Unix Makefiles
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi

mkdir -p "$HDF5_WORKDIR"

echo "== [1/5] Clone/update HDF5 repo =="
if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/HDFGroup/hdf5.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

echo "== [2/5] Select latest stable tag < 2.0.0 =="
# Stable tags look like: hdf5-1_14_3
latest_tag="$(
  git tag -l 'hdf5-[0-9]_*' \
  | grep -E '^hdf5-[0-9]+_[0-9]+_[0-9]+$' \
  | awk -F'[-_]' '
      {
        maj=$2; min=$3; pat=$4;
        if (maj < 2) printf "%03d.%03d.%03d %s\n", maj, min, pat, $0
      }' \
  | sort -V \
  | tail -n 1 \
  | awk '{print $2}'
)"

if [[ -z "$latest_tag" ]]; then
  echo "ERROR: Could not determine a stable pre-2.0.0 tag."
  exit 1
fi

echo "Latest pre-2.0.0 stable tag: $latest_tag"

branch="release/$latest_tag"
git switch -C "$branch" "$latest_tag"

ver="$latest_tag"
BUILD_DIR="$HDF5_WORKDIR/build-$ver"
INSTALL_DIR="$HDF5_WORKDIR/install-$ver"

echo "== [3/5] Configure + build + install HDF5 ($ver) =="
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

cmake -S "$REPO_DIR" -B "$BUILD_DIR" -G "$GENERATOR" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DHDF5_ENABLE_THREADSAFE="$THREADSAFE" \
  -DHDF5_BUILD_HL_LIB=OFF \
  -DHDF5_BUILD_CPP_LIB=OFF \
  -DHDF5_BUILD_FORTRAN=OFF \
  -DHDF5_BUILD_JAVA=OFF \
  -DBUILD_TESTING=OFF

cmake --build "$BUILD_DIR" -j"$MAKE_JOBS"
cmake --install "$BUILD_DIR"



# -------------------------------
#  helpers
HDF5_ROOT="$INSTALL_DIR"
HDF5_DIR="$HDF5_ROOT/cmake"
echo "== Post-install sanity: cmake config dir contents =="
ls -1 "$HDF5_DIR" || true
# Some projects expect canonical capitalized config filenames.
# Make symlinks so both lowercase and uppercase work.
ln -sf "$HDF5_DIR/hdf5-config.cmake"         "$HDF5_DIR/HDF5Config.cmake"
ln -sf "$HDF5_DIR/hdf5-config-version.cmake" "$HDF5_DIR/HDF5ConfigVersion.cmake"
# Avoid stale cached values from the environment (helps when reconfiguring repeatedly)
unset HDF5_INCLUDE_DIRS HDF5_LIBRARIES HDF5_C_LIBRARY HDF5_HL_LIBRARY || true
# --------------------------------



echo "== [4/5] Patch h5cc in-place (add -show) =="
HDF5_ROOT="$INSTALL_DIR"
H5CC="$HDF5_ROOT/bin/h5cc"
REAL="$HDF5_ROOT/bin/h5cc.real"

if [[ ! -x "$H5CC" ]]; then
  echo "ERROR: installed h5cc not found at $H5CC"
  exit 1
fi

if [[ ! -f "$HDF5_ROOT/lib/libhdf5.settings" ]]; then
  echo "ERROR: missing $HDF5_ROOT/lib/libhdf5.settings (install looks incomplete)"
  exit 1
fi

if [[ ! -e "$REAL" ]]; then
  mv "$H5CC" "$REAL"
fi

cat > "$H5CC" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

prg="$0"
if [[ ! -e "$prg" ]]; then
  case "$prg" in
    (*/*) exit 1 ;;
    (*) prg="$(command -v -- "$prg")" || exit 1 ;;
  esac
fi

dir="$(cd -P -- "$(dirname -- "$prg")/.." && pwd -P)"

export PKG_CONFIG_PATH="$dir/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

showconfigure() {
  cat "$dir/lib/libhdf5.settings"
}

case "${1:-}" in
  -showconfig)
    showconfigure
    exit 0
    ;;
  -show)
    # classic wrapper behavior expected by CMake FindHDF5
    echo "/usr/bin/cc $(pkg-config --define-variable=prefix=$dir --cflags --libs hdf5)"
    exit 0
    ;;
  *)
    exec /usr/bin/cc "$@" $(pkg-config --define-variable=prefix=$dir --cflags --libs hdf5)
    ;;
esac
EOF
chmod +x "$H5CC"

echo "Patched wrapper: $H5CC"
echo "Backup saved as : $REAL"
echo
echo "h5cc -show:"
"$H5CC" -show | head -n 1
echo

echo "== [5/5] Quick CMake find test =="
TEST_DIR="$(mktemp -d /tmp/hdf5-findtest.XXXXXX)"
cat > "$TEST_DIR/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(hdf5_findtest C)

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)

# Ensure CMake can see the installed HDF5 config + pkg-config files
set(HDF5_ROOT "$HDF5_ROOT")
set(CMAKE_PREFIX_PATH "\${HDF5_ROOT};\${CMAKE_PREFIX_PATH}")

find_package(HDF5 REQUIRED COMPONENTS C)

add_executable(hdf5_findtest main.c)
target_include_directories(hdf5_findtest PRIVATE \${HDF5_INCLUDE_DIRS})
target_link_libraries(hdf5_findtest PRIVATE \${HDF5_LIBRARIES})
EOF

cat > "$TEST_DIR/main.c" <<'EOF'
#include "hdf5.h"
#include <stdio.h>
int main(void) {
  printf("HDF5: %s\n", H5_VERSION);
  return 0;
}
EOF

cmake -S "$TEST_DIR" -B "$TEST_DIR/build" -G "$GENERATOR" \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT"

cmake --build "$TEST_DIR/build" -j"$MAKE_JOBS"
"$TEST_DIR/build/hdf5_findtest"

echo
echo "SUCCESS."
echo "Installed HDF5 root:"
echo "  $HDF5_ROOT"
echo
echo "To use it in your shell:"
echo "  export HDF5_ROOT=\"$HDF5_ROOT\""
echo "  export HDF5_DIR=\"$HDF5_ROOT/cmake\""
echo "  export PKG_CONFIG_PATH=\"$HDF5_ROOT/lib/pkgconfig:\${PKG_CONFIG_PATH:-}\""