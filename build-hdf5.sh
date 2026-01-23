#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# build-hdf5.sh  (matches your geant4-build.sh style)
#
#   1) optional Homebrew deps
#   2) clone/update HDF5 repo
#   3) checkout latest stable 1.x tag (pre-2.0)
#   4) configure + build + install
#   5) patch h5cc in-place to support -show (for CMake FindHDF5)
#   6) add HDF5Config.cmake symlinks (so FindHDF5 can prefer config-mode)
#   7) quick CMake find test (find_package(HDF5) + compile dummy)
#   8) optional update ~/.zshrc HDF5_ROOT/HDF5_DIR + source it (zsh-only)
#
# Run:
#   chmod +x build-hdf5.sh
#   ./build-hdf5.sh
###############################################################################

# -----------------------------
# helpers
# -----------------------------
tolower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

ask_yn() {
  # usage: ask_yn "Question?" default(Y/N)
  local q="$1" d="$2" a
  read -r -p "$q " a || true
  a="$(tolower "${a:-}")"
  if [[ "$d" == "Y" ]]; then
    [[ -z "$a" || "$a" == "y" || "$a" == "yes" ]]
  else
    [[ "$a" == "y" || "$a" == "yes" ]]
  fi
}

# -----------------------------
# preflight: Homebrew
# -----------------------------
echo "Preflight: Homebrew"
if command -v brew >/dev/null 2>&1; then
  if ask_yn "Install/verify Homebrew dependencies now? [y/N]:" "N"; then
    brew update
    brew install cmake ninja pkgconf git wget python make || true
    echo "Homebrew dependencies step complete"
  fi
else
  echo "brew not found, assuming deps already present"
fi
echo

# -----------------------------
# User choices
# -----------------------------
HDF5_WORKDIR="${HDF5_WORKDIR:-$HOME/HDF5}"

if ask_yn "Create workdir '$HDF5_WORKDIR'? [Y/n]:" "Y"; then
  mkdir -p "$HDF5_WORKDIR"
fi

read -r -p "Numeric suffix for build/install dirs (digits or empty): " SUFFIX || true
if [[ -n "$SUFFIX" && ! "$SUFFIX" =~ ^[0-9]+$ ]]; then
  echo "ERROR: suffix must be digits only"
  exit 1
fi

ZSHRC="$HOME/.zshrc"
DO_UPDATE_ZSHRC="no"
read -r -p "After install, update ~/.zshrc HDF5_ROOT/HDF5_DIR to this install? [Y/n]: " ans || true
ans="${ans:-Y}"
if [[ "$ans" =~ ^[Yy]$ ]]; then
  DO_UPDATE_ZSHRC="yes"
fi
echo

# Prefer Ninja if installed, else Unix Makefiles
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi

# -----------------------------
# Clone/update HDF5
# -----------------------------
echo "[1/6] Clone/update HDF5"
REPO_DIR="$HDF5_WORKDIR/hdf5"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/HDFGroup/hdf5.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

# -----------------------------
# Select latest stable tag < 2.0.0
# -----------------------------
echo "[2/6] Select latest stable tag (pre-2.0.0)"

# Stable tags look like: hdf5-1_14_3  (exclude rc, exclude 2.x)
LATEST_TAG="$(
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

[[ -z "$LATEST_TAG" ]] && { echo "ERROR: could not determine a stable pre-2.0.0 tag"; exit 1; }

echo "Latest pre-2.0.0 stable tag: $LATEST_TAG"
git switch -C "release/$LATEST_TAG" "$LATEST_TAG"

VER="$LATEST_TAG"
cd "$HDF5_WORKDIR"
echo

# -----------------------------
# Configure + build + install
# -----------------------------
echo "[3/6] Configure + build + install HDF5 ($VER)"

BUILD_DIR="$HDF5_WORKDIR/build-$VER${SUFFIX:+-$SUFFIX}"
INSTALL_DIR="$HDF5_WORKDIR/install-$VER${SUFFIX:+-$SUFFIX}"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

cmake -S "$REPO_DIR" -B "$BUILD_DIR" -G "$GENERATOR" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DHDF5_ENABLE_THREADSAFE=ON \
  -DHDF5_BUILD_HL_LIB=OFF \
  -DHDF5_BUILD_CPP_LIB=OFF \
  -DHDF5_BUILD_FORTRAN=OFF \
  -DHDF5_BUILD_JAVA=OFF \
  -DBUILD_TESTING=OFF

JOBS="$(sysctl -n hw.ncpu)"
cmake --build "$BUILD_DIR" -j"$JOBS"
cmake --install "$BUILD_DIR"

echo "Installed to $INSTALL_DIR"
echo

# -----------------------------
# Patch h5cc for FindHDF5 (-show)
# -----------------------------
echo "[4/6] Patch h5cc in-place (add -show)"

HDF5_ROOT="$INSTALL_DIR"
HDF5_DIR="$HDF5_ROOT/cmake"
H5CC="$HDF5_ROOT/bin/h5cc"
REAL="$HDF5_ROOT/bin/h5cc.real"

[[ -x "$H5CC" ]] || { echo "ERROR: installed h5cc not found at $H5CC"; exit 1; }
[[ -f "$HDF5_ROOT/lib/libhdf5.settings" ]] || { echo "ERROR: missing $HDF5_ROOT/lib/libhdf5.settings"; exit 1; }

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
    # expected by CMake FindHDF5 module-mode detection
    echo "/usr/bin/cc $(pkg-config --define-variable=prefix=$dir --cflags --libs hdf5)"
    exit 0
    ;;
  *)
    exec /usr/bin/cc "$@" $(pkg-config --define-variable=prefix=$dir --cflags --libs hdf5)
    ;;
esac
EOF

chmod +x "$H5CC"

echo "h5cc -show:"
"$H5CC" -show | head -n 1
echo

# -----------------------------
# Add HDF5Config.cmake symlink names (sometimes expected)
# -----------------------------
echo "[5/6] Ensure HDF5Config.cmake symlink names exist"

if [[ -d "$HDF5_DIR" ]]; then
  ln -sf "$HDF5_DIR/hdf5-config.cmake"         "$HDF5_DIR/HDF5Config.cmake"
  ln -sf "$HDF5_DIR/hdf5-config-version.cmake" "$HDF5_DIR/HDF5ConfigVersion.cmake"
fi

# Clear any stale vars if the user is running inside an already-configured shell
unset HDF5_INCLUDE_DIRS HDF5_LIBRARIES HDF5_C_LIBRARY HDF5_HL_LIBRARY || true
echo



# -----------------------------
# Update ~/.zshrc + source it (zsh-only)
# -----------------------------
if [[ "${DO_UPDATE_ZSHRC:-no}" == "yes" ]]; then
  [[ -f "$ZSHRC" ]] || : > "$ZSHRC"

  echo "Updating ~/.zshrc HDF5_ROOT/HDF5_DIR -> $HDF5_ROOT"

  tmp="$(mktemp)"

  # Update or append HDF5_ROOT
  if grep -qE '^[[:space:]]*export[[:space:]]+HDF5_ROOT=' "$ZSHRC"; then
    sed -E "s|^[[:space:]]*export[[:space:]]+HDF5_ROOT=.*$|export HDF5_ROOT=\"$HDF5_ROOT\"|g" \
      "$ZSHRC" > "$tmp"
    mv "$tmp" "$ZSHRC"
  else
    cat "$ZSHRC" > "$tmp"
    cat >> "$tmp" <<EOF

# ╭───────────────────────────────╮
# │         🧬 HDF5               │
# ╰───────────────────────────────╯
export HDF5_ROOT="$HDF5_ROOT"
export HDF5_DIR="\$HDF5_ROOT/cmake"
path=("\$HDF5_ROOT/bin" \$path)
export PKG_CONFIG_PATH="\$HDF5_ROOT/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
EOF
    mv "$tmp" "$ZSHRC"
  fi

  # Ensure HDF5_DIR matches
  tmp="$(mktemp)"
  if grep -qE '^[[:space:]]*export[[:space:]]+HDF5_DIR=' "$ZSHRC"; then
    sed -E "s|^[[:space:]]*export[[:space:]]+HDF5_DIR=.*$|export HDF5_DIR=\"\$HDF5_ROOT/cmake\"|g" \
      "$ZSHRC" > "$tmp"
    mv "$tmp" "$ZSHRC"
  else
    rm -f "$tmp" || true
  fi

  echo "~/.zshrc updated."

  # Re-export for current script environment
  export HDF5_ROOT="$HDF5_ROOT"
  export HDF5_DIR="$HDF5_ROOT/cmake"

  # IMPORTANT: don't `source ~/.zshrc` inside bash (causes setopt errors).
  # Instead: run a login zsh to source it.
  echo "Reloading ~/.zshrc via zsh..."
  zsh -lc "source \"$HOME/.zshrc\" >/dev/null 2>&1 || true"
fi









# -----------------------------
# Quick CMake find test
# -----------------------------
echo "[6/6] Quick CMake find test"

TESTDIR="$(mktemp -d /tmp/hdf5test.XXXXXX)"

cat > "$TESTDIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(hdf5test C)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)

find_package(HDF5 REQUIRED CONFIG)

add_executable(hdf5test main.c)
target_link_libraries(hdf5test PRIVATE hdf5-shared)   # or hdf5-static
# If you ever build HL, you can also link: hdf5_hl-shared
EOF

cat > "$TESTDIR/main.c" <<'EOF'
#include "hdf5.h"
#include <stdio.h>
int main(void) {
  printf("HDF5: %s\n", H5_VERSION);
  return 0;
}
EOF

cmake -S "$TESTDIR" -B "$TESTDIR/build" -G "$GENERATOR" \
  -DHDF5_DIR="$HDF5_ROOT/cmake" \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;/opt/homebrew" \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON

cmake --build "$TESTDIR/build" -j"$JOBS"

echo "Test run:"
"$TESTDIR/build/hdf5test" || true
echo


echo
echo "DONE: HDF5 $VER ready"