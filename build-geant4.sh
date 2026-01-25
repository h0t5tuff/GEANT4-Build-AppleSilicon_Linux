#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#   1) ensure Homebrew deps
#   2) clone/update Geant4 repo
#   3) checkout latest stable tag
#   4) configure + build (with retries) + install
#   5) quick CMake test (find_package(Geant4) + link G4analysis)
#   6) update ~/.zshrc Geant4 block
#
# Run:
#   chmod +x build-geant4.sh
#   ./build-geant4.sh
###############################################################################

tolower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

ask_yn() {
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
# preflight
# -----------------------------
echo "Preflight: Homebrew"
if command -v brew >/dev/null 2>&1; then
  if ask_yn "Install/verify Homebrew dependencies now? [y/N]:" "N"; then
    brew update
    brew install cmake ninja pkgconf git wget expat xerces-c qt python make libx11 clhep jpeg libxi libxmu open-mpi|| true
    echo "Homebrew dependencies step complete"
  fi
else
  echo "brew not found, assuming deps already present"
fi
echo


echo "Preflight: HDF5"
: "${HDF5_ROOT:?ERROR: export HDF5_ROOT first}"

if [[ -z "${HDF5_DIR:-}" ]]; then
  if [[ -d "$HDF5_ROOT/cmake" ]]; then
    HDF5_DIR="$HDF5_ROOT/cmake"
  else
    echo "ERROR: HDF5_DIR not set and $HDF5_ROOT/cmake not found"
    exit 1
  fi
fi

if [[ ! -x "$HDF5_ROOT/bin/h5cc" ]]; then
  echo "ERROR: h5cc not found in $HDF5_ROOT/bin"
  exit 1
fi

echo "HDF5_ROOT=$HDF5_ROOT"
echo "HDF5_DIR =$HDF5_DIR"
"$HDF5_ROOT/bin/h5cc" -showconfig | egrep -i "HDF5 Version|Threadsafety" || true
echo

# -----------------------------
# User choices
# -----------------------------
GEANT4_WORKDIR="${GEANT4_WORKDIR:-$HOME/Documents/GEANT4}"

if ask_yn "Create workdir '$GEANT4_WORKDIR'? [Y/n]:" "Y"; then
  mkdir -p "$GEANT4_WORKDIR"
fi

read -r -p "Numeric suffix for build/install dirs (digits or empty): " SUFFIX || true
if [[ -n "$SUFFIX" && ! "$SUFFIX" =~ ^[0-9]+$ ]]; then
  echo "ERROR: suffix must be digits only"
  exit 1
fi

ZSHRC="$HOME/.zshrc"
DO_UPDATE_ZSHRC="no"
read -r -p "After install, update ~/.zshrc GEANT4_BASE to this install? [Y/n]: " ans
ans="${ans:-Y}"
if [[ "$ans" =~ ^[Yy]$ ]]; then
  DO_UPDATE_ZSHRC="yes"
fi

# -----------------------------
# Clone/update Geant4
# -----------------------------
echo "[1/5] Clone/update Geant4"
REPO_DIR="$GEANT4_WORKDIR/geant4"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/Geant4/geant4.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

LATEST="$(git tag -l 'v*' --sort=version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)"
[[ -z "$LATEST" ]] && { echo "ERROR: no stable tag found"; exit 1; }

echo "Latest stable tag: $LATEST"
git switch -C "release/${LATEST#v}" "$LATEST"
VER="$LATEST"
cd "$GEANT4_WORKDIR"
echo

# -----------------------------
# Configure
# -----------------------------
echo "[2/5] Configure Geant4 ($VER)"

BUILD_DIR="$GEANT4_WORKDIR/build-$VER${SUFFIX:+-$SUFFIX}"
INSTALL_DIR="$GEANT4_WORKDIR/install-$VER${SUFFIX:+-$SUFFIX}"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# Choose generator
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi

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
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;/opt/homebrew"

# -----------------------------
# Build with retries
# -----------------------------
echo "[3/5] Build (with retries)"

JOBS="$(sysctl -n hw.ncpu)"
MAX_RETRY=5
SLEEP_SEC=10
TRY=1

while true; do
  set +e
  cmake --build "$BUILD_DIR" -j"$JOBS"
  RC=$?
  set -e

  [[ $RC -eq 0 ]] && break
  [[ $TRY -ge $MAX_RETRY ]] && { echo "Build failed permanently"; exit $RC; }

  echo "Retry $TRY/$MAX_RETRY in $SLEEP_SEC s..."
  TRY=$((TRY+1))
  sleep "$SLEEP_SEC"
done
echo

# -----------------------------
# Install
# -----------------------------
echo "[4/5] Install"
cmake --install "$BUILD_DIR"
echo "Installed to $INSTALL_DIR"
echo

# -----------------------------
# Update ~/.zshrc
# -----------------------------
if [[ "${DO_UPDATE_ZSHRC:-no}" == "yes" ]]; then
  ZSHRC="${ZSHRC:-$HOME/.zshrc}"

  [[ -f "$ZSHRC" ]] || : > "$ZSHRC"

  echo "Updating existing GEANT4_BASE in ~/.zshrc -> $INSTALL_DIR"

  tmp="$(mktemp)"
  if grep -qE '^[[:space:]]*export[[:space:]]+GEANT4_BASE=' "$ZSHRC"; then
    sed -E "s|^[[:space:]]*export[[:space:]]+GEANT4_BASE=.*$|export GEANT4_BASE=\"$INSTALL_DIR\"|g" \
      "$ZSHRC" > "$tmp"
  else
    cat "$ZSHRC" > "$tmp"
    cat >> "$tmp" <<EOF

# ╭───────────────────────────────╮
# │     🧬 Geant4                 │
# ╰───────────────────────────────╯
export GEANT4_BASE="$INSTALL_DIR"
if [[ -f "\$GEANT4_BASE/bin/geant4.sh" ]]; then
  source "\$GEANT4_BASE/bin/geant4.sh"
fi
export Geant4_DIR="\$GEANT4_BASE/lib/cmake/Geant4"
path=("$GEANT4_BASE/bin" $path)
export G4VIS_DEFAULT_DRIVER=OGLSQt
EOF
  fi
  mv "$tmp" "$ZSHRC"
  echo "~/.zshrc updated."

  export GEANT4_BASE="$INSTALL_DIR"
  export Geant4_DIR="$GEANT4_BASE/lib/cmake/Geant4"
fi

# -----------------------------
# Quick test
# -----------------------------
echo "[5/5] Quick CMake test"
TESTDIR="$(mktemp -d /tmp/g4test.XXXXXX)"

cat > "$TESTDIR/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(g4test CXX)
find_package(Geant4 REQUIRED)
add_executable(g4test main.cc)
target_link_libraries(g4test PRIVATE Geant4::G4analysis)
EOF

cat > "$TESTDIR/main.cc" <<EOF
#include "G4Version.hh"
#include <iostream>
int main(){ std::cout << G4VERSION_NUMBER << "\n"; }
EOF

cmake -S "$TESTDIR" -B "$TESTDIR/build" -G "$GENERATOR" \
  -DGeant4_DIR="$INSTALL_DIR/lib/cmake/Geant4" \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;/opt/homebrew"

cmake --build "$TESTDIR/build" -j"$JOBS"

echo "Linkage check:"
otool -L "$TESTDIR/build/g4test" | egrep 'G4analysis|hdf5' || true










echo
echo "DONE: Geant4 $VER ready"