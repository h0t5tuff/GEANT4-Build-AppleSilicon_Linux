#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#   1) preflight: Geant4 + HDF5 (needs HDF5 C++ libs)
#   2) clone/update remage repo
#   3) checkout latest tag (or keep main)
#   4) configure + build (with retries) + install
#   5) quick run/link checks
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


# Preflight
echo "Preflight: Geant4"
: "${GEANT4_BASE:?ERROR: export GEANT4_BASE first (e.g. ~/GEANT4/install-v11.4.0-5)}"
if [[ ! -f "$GEANT4_BASE/lib/cmake/Geant4/Geant4Config.cmake" ]]; then
  echo "ERROR: Geant4Config.cmake not found under: $GEANT4_BASE/lib/cmake/Geant4"
  exit 1
fi
echo "GEANT4_BASE=$GEANT4_BASE"
echo

echo "Preflight: HDF5 (must have C++ libs for remage)"
: "${HDF5_ROOT:?ERROR: export HDF5_ROOT first}"
HDF5_DIR="${HDF5_DIR:-$HDF5_ROOT/cmake}"
if [[ ! -d "$HDF5_DIR" ]]; then
  echo "ERROR: HDF5_DIR not found: $HDF5_DIR"
  exit 1
fi
if [[ ! -x "$HDF5_ROOT/bin/h5cc" ]]; then
  echo "ERROR: h5cc not found: $HDF5_ROOT/bin/h5cc"
  exit 1
fi
echo "HDF5_ROOT=$HDF5_ROOT"
echo "HDF5_DIR =$HDF5_DIR"
"$HDF5_ROOT/bin/h5cc" -showconfig | egrep -i "HDF5 Version|Threadsafety" || true
echo

# Hard check for HDF5 C++ library presence (names vary a bit across builds)
if ! ls "$HDF5_ROOT/lib"/libhdf5_cpp* >/dev/null 2>&1; then
  echo "ERROR: HDF5 C++ library not found (expected libhdf5_cpp* in $HDF5_ROOT/lib)."
  echo "       Rebuild HDF5 with: -DHDF5_BUILD_CPP_LIB=ON"
  exit 1
fi



echo "User choices"
REMAGE_WORKDIR="${REMAGE_WORKDIR:-$HOME/Documents/REMAGE}"
if ask_yn "Create workdir '$REMAGE_WORKDIR'? [Y/n]:" "Y"; then
  mkdir -p "$REMAGE_WORKDIR"
fi

read -r -p "Numeric suffix for build/install dirs (digits or empty): " SUFFIX || true
if [[ -n "$SUFFIX" && ! "$SUFFIX" =~ ^[0-9]+$ ]]; then
  echo "ERROR: suffix must be digits only"
  exit 1
fi

USE_TAG="no"
if ask_yn "Checkout latest remage tag (instead of staying on main)? [y/N]:" "N"; then
  USE_TAG="yes"
fi

# Generator
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi

echo
echo "[1/5] Clone/update remage"
REPO_DIR="$REMAGE_WORKDIR/remage"
if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/legend-exp/remage.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

if [[ "$USE_TAG" == "yes" ]]; then
  LATEST_TAG="$(
    git tag -l 'v*' --sort=version:refname \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | tail -n 1
  )"
  if [[ -z "$LATEST_TAG" ]]; then
    echo "ERROR: could not find a stable vX.Y.Z tag; staying on main."
    VER="main"
    git switch main
    git pull --ff-only || true
  else
    echo "Latest stable tag: $LATEST_TAG"
    git switch -C "release/${LATEST_TAG#v}" "$LATEST_TAG"
    VER="$LATEST_TAG"
  fi
else
  VER="main"
  git switch main
  git pull --ff-only || true
fi

cd "$REMAGE_WORKDIR"
echo

echo "[2/5] Configure remage ($VER)"
BUILD_DIR="$REMAGE_WORKDIR/build-remage-$VER${SUFFIX:+-$SUFFIX}"
INSTALL_DIR="$REMAGE_WORKDIR/install-remage-$VER${SUFFIX:+-$SUFFIX}"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# Important: remage uses -Werror; keep your toolchain consistent (arm64)
cmake -S "$REPO_DIR" -B "$BUILD_DIR" -G "$GENERATOR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
  -DPython3_EXECUTABLE="$Python3_EXECUTABLE" \
  -DBUILD_TESTING=ON \
  -DROOT_DIR="$ROOT_DIR" \
  -DHDF5_DIR="$HDF5_DIR" \
  -DHDF5_ROOT="$HDF5_ROOT" \
  -DGeant4_DIR="$Geant4_DIR" \
  -DGeant4_DIR="$GEANT4_BASE/lib/cmake/Geant4" \
  -DHDF5_DIR="$HDF5_DIR" \
  -DCMAKE_PREFIX_PATH="$GEANT4_BASE;$HDF5_ROOT;/opt/homebrew" \
  -DRMG_USE_ROOT=OFF \
  -DRMG_USE_BXDECAY0=OFF \
  -DRMG_BUILD_DOCS=OFF \
  -DRMG_BUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;$BXDECAY0_PREFIX;$GEANT4_BASE;/opt/homebrew/opt/root;/opt/homebrew" 


echo
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

echo "[4/5] Install"
cmake --install "$BUILD_DIR"
echo "Installed to $INSTALL_DIR"
echo

echo "[5/5] Quick checks"
if [[ -x "$INSTALL_DIR/bin/remage" ]]; then
  echo "remage binary:"
  "$INSTALL_DIR/bin/remage" --help >/dev/null && echo "  OK: remage runs"
else
  echo "WARNING: remage binary not found at $INSTALL_DIR/bin/remage"
fi

# Link sanity: show whether remage (or its libs) see Geant4/HDF5
if ls "$INSTALL_DIR/lib"/*.dylib >/dev/null 2>&1; then
  echo "Example linkage (first remage dylib):"
  first="$(ls -1 "$INSTALL_DIR/lib"/*.dylib | head -n 1)"
  otool -L "$first" | egrep 'Geant4|G4|hdf5' || true
fi

echo
echo "DONE: remage $VER ready at:"
echo "  $INSTALL_DIR"


