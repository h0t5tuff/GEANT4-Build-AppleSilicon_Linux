#!/usr/bin/env bash
set -euo pipefail

# One-command pipeline:
#   1) clone/update GEANT4 repo
#   2) checkout latest stable
#   3) build+install GEANT4
#   5) quick CMake find test (find_package(GEANT4) + compile dummy)

# # chmod +x build-geant4.sh && ./build-geant4.sh

# User-tunable knobs:
GEANT4_WORKDIR="${GEANT4_WORKDIR:-$HOME/GEANT4}"
REPO_DIR="$GEANT4_WORKDIR/geant4"

# You should already have these:
HDF5_ROOT="${HDF5_ROOT:-}"
HDF5_DIR="${HDF5_DIR:-}"

# Build settings
MAKE_JOBS="${MAKE_JOBS:-$(sysctl -n hw.ncpu)}"
RETRY_BUILD_MAX="${RETRY_BUILD_MAX:-5}"     # number of build retries if it fails
RETRY_SLEEP_SEC="${RETRY_SLEEP_SEC:-10}"    # wait between retries

# Choose generator
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi

# -----------------------------
# Preflight checks
# -----------------------------
echo "== Preflight =="

if [[ -z "$HDF5_ROOT" ]]; then
  echo "ERROR: HDF5_ROOT is not set. Example:"
  echo "  export HDF5_ROOT=\"$HOME/HDF5/install-hdf5-1_14_3\""
  exit 1
fi

if [[ -z "$HDF5_DIR" ]]; then
  # default to common layout
  if [[ -d "$HDF5_ROOT/cmake" ]]; then
    HDF5_DIR="$HDF5_ROOT/cmake"
  else
    echo "ERROR: HDF5_DIR is not set and '$HDF5_ROOT/cmake' not found."
    exit 1
  fi
fi

if [[ ! -x "$HDF5_ROOT/bin/h5cc" ]]; then
  echo "ERROR: '$HDF5_ROOT/bin/h5cc' not found/executable. HDF5 install looks wrong."
  exit 1
fi

echo "HDF5_ROOT=$HDF5_ROOT"
echo "HDF5_DIR =$HDF5_DIR"
echo "GENERATOR=$GENERATOR"
echo "MAKE_JOBS=$MAKE_JOBS"
echo

mkdir -p "$GEANT4_WORKDIR"

# -----------------------------
# Clone/update Geant4
# -----------------------------
echo "== [1/6] Clone/update Geant4 repo =="
if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/Geant4/geant4.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

# latest stable tag vX.Y.Z
latest="$(
  git tag -l 'v*' --sort=version:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | tail -n 1
)"

if [[ -z "$latest" ]]; then
  echo "ERROR: Could not determine latest stable Geant4 tag."
  exit 1
fi

echo "Latest stable tag: $latest"
branch="release/${latest#v}"
git switch -C "$branch" "$latest"

ver="$latest"
BUILD_DIR="$GEANT4_WORKDIR/build-$ver"
INSTALL_DIR="$GEANT4_WORKDIR/install-$ver"

echo
echo "== [2/6] Configure Geant4 ($ver) =="
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# NOTE:
# - rely on your patched h5cc to support -show (module-mode FindHDF5 may call it).
# - DO NOT delete build dir on re-run; this keeps downloads/caches.
cmake -S "$REPO_DIR" -B "$BUILD_DIR" -G "$GENERATOR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DGEANT4_BUILD_MULTITHREADED=ON \
  -DGEANT4_INSTALL_DATA=ON \
  -DGEANT4_INSTALL_EXAMPLES=ON \
  -DGEANT4_USE_SYSTEM_EXPAT=ON \
  -DGEANT4_USE_GDML=ON \
  -DGEANT4_USE_QT=ON \
  -DGEANT4_USE_OPENGL=ON \
  -DGEANT4_USE_HDF5=ON \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;/opt/homebrew" \
  -DHDF5_DIR="$HDF5_DIR"

echo
echo "== [3/6] Build with retries (handles flaky dataset downloads) =="

attempt=1
while true; do
  set +e
  cmake --build "$BUILD_DIR" -j"$MAKE_JOBS"
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    echo "Build succeeded."
    break
  fi

  echo
  echo "Build failed (attempt $attempt/$RETRY_BUILD_MAX, exit=$rc)."

  # Common failure mode: dataset download / hash mismatch.
  # Retrying usually succeeds because partial downloads get replaced/continued by CMake scripts.
  if [[ $attempt -ge $RETRY_BUILD_MAX ]]; then
    echo "ERROR: build still failing after $RETRY_BUILD_MAX attempts."
    echo "Tip: check the error above; if it's always a dataset URL failure,"
    echo "     you can rerun later, or try forcing IPv4 for curl (system-dependent),"
    echo "     or manually download datasets into '$BUILD_DIR/data'."
    exit $rc
  fi

  attempt=$((attempt + 1))
  echo "Retrying in ${RETRY_SLEEP_SEC}s..."
  sleep "$RETRY_SLEEP_SEC"
done

echo
echo "== [4/6] Install =="
cmake --install "$BUILD_DIR"

echo
echo "== [5/6] Post-install sanity checks =="
"$INSTALL_DIR/bin/geant4-config" --version
"$INSTALL_DIR/bin/geant4-config" --has-feature hdf5
"$INSTALL_DIR/bin/geant4-config" --has-feature qt || true

echo
echo "libG4analysis -> hdf5 linkage (install tree):"
otool -L "$INSTALL_DIR/lib/libG4analysis.dylib" | egrep 'hdf5|HDF5' || true

# -----------------------------
# Quick CMake link + runtime load test
# -----------------------------
echo
echo "== [6/6] Quick CMake test (link to G4analysis and show runtime HDF5 load) =="

TEST_DIR="$(mktemp -d /tmp/g4hdf5check.XXXXXX)"
cat > "$TEST_DIR/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(g4hdf5check CXX)

find_package(Geant4 REQUIRED)  # keep simple: Geant4Config already knows its libs
add_executable(g4hdf5check main.cc)
target_link_libraries(g4hdf5check PRIVATE Geant4::G4analysis)
EOF

cat > "$TEST_DIR/main.cc" <<'EOF'
#include "G4Version.hh"
#include <iostream>
int main() {
  std::cout << "Geant4: " << G4VERSION_NUMBER << "\n";
  return 0;
}
EOF

cmake -S "$TEST_DIR" -B "$TEST_DIR/build" -G "$GENERATOR" \
  -DGeant4_DIR="$INSTALL_DIR/lib/cmake/Geant4" \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;/opt/homebrew"

cmake --build "$TEST_DIR/build" -j"$MAKE_JOBS"

echo
echo "Runtime-loaded libs containing 'hdf5' (DYLD_PRINT_LIBRARIES):"
DYLD_PRINT_LIBRARIES=1 "$TEST_DIR/build/g4hdf5check" 2>&1 | grep -i hdf5 || true

echo
echo "Linkage (otool -L):"
otool -L "$TEST_DIR/build/g4hdf5check" | egrep 'G4analysis|hdf5' || true

echo
echo "SUCCESS."
echo "Installed Geant4:"
echo "  $INSTALL_DIR"
echo
echo "Recommended env (your .zshrc style):"
echo "  export GEANT4_BASE=\"$INSTALL_DIR\""
echo "  source \"\$GEANT4_BASE/bin/geant4.sh\""
echo "  export Geant4_DIR=\"\$GEANT4_BASE/lib/cmake/Geant4\""
echo "  export G4VIS_DEFAULT_DRIVER=OGLSQt"