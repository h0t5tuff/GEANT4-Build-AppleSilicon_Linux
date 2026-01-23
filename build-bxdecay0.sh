#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#   1) preflight: Geant4 + git-lfs
#   2) clone/update bxdecay0
#   3) configure + build (with retries) + test + install
#   4) (optional) update ~/.zshrc with BXDECAY0_* block
#
# Run:
#   chmod +x build-bxdecay0.sh
#   ./build-bxdecay0.sh
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

echo "Preflight:"

: "${GEANT4_BASE:?ERROR: export GEANT4_BASE first (e.g. ~/GEANT4/install-v11.4.0-5)}"
Geant4_DIR="${Geant4_DIR:-$GEANT4_BASE/lib/cmake/Geant4}"
if [[ ! -f "$Geant4_DIR/Geant4Config.cmake" ]]; then
  echo "ERROR: Geant4Config.cmake not found under: $Geant4_DIR"
  exit 1
fi
echo "GEANT4_BASE=$GEANT4_BASE"
echo "Geant4_DIR  =$Geant4_DIR"
echo


if ! command -v git-lfs >/dev/null 2>&1; then
  echo "git-lfs not found."
  if command -v brew >/dev/null 2>&1 && ask_yn "Install git-lfs via Homebrew now? [y/N]:" "N"; then
    brew install git-lfs
  else
    echo "ERROR: git-lfs is required for bxdecay0 (repo uses LFS)."
    exit 1
  fi
fi
git lfs install >/dev/null 2>&1 || true
echo "git-lfs OK"
echo





echo "User choices:"

BXDECAY0_HOME="${BXDECAY0_HOME:-$HOME/BXDECAY0}"
if ask_yn "Create workdir '$BXDECAY0_HOME'? [Y/n]:" "Y"; then
  mkdir -p "$BXDECAY0_HOME"
fi

read -r -p "Numeric suffix for build/install dirs (digits or empty): " SUFFIX || true
if [[ -n "$SUFFIX" && ! "$SUFFIX" =~ ^[0-9]+$ ]]; then
  echo "ERROR: suffix must be digits only"
  exit 1
fi

DO_UPDATE_ZSHRC="no"
if ask_yn "After install, update ~/.zshrc with BXDECAY0_HOME/PREFIX/PKG_CONFIG_PATH? [Y/n]:" "Y"; then
  DO_UPDATE_ZSHRC="yes"
fi

# generator
if command -v ninja >/dev/null 2>&1; then
  GENERATOR="${GENERATOR:-Ninja}"
else
  GENERATOR="${GENERATOR:-Unix Makefiles}"
fi


echo
echo "[1/4] Clone/update bxdecay0"
REPO_DIR="$BXDECAY0_HOME/bxdecay0"
if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/BxCppDev/bxdecay0.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

# Prefer latest tag if tags exist; otherwise stay on current branch
LATEST_TAG="$(git tag -l 'v*' --sort=version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1 || true)"
if [[ -n "$LATEST_TAG" ]]; then
  echo "Latest tag: $LATEST_TAG"
  git switch -C "release/${LATEST_TAG#v}" "$LATEST_TAG"
  VER="$LATEST_TAG"
else
  git rev-parse --abbrev-ref HEAD >/dev/null 2>&1 || git switch main
  git pull --ff-only || true
  VER="main"
fi

echo "Fetching LFS files..."
git lfs pull
cd "$BXDECAY0_HOME"
echo




echo "[2/4] Configure ($VER)"
BUILD_DIR="$BXDECAY0_HOME/build-bxdecay0-$VER${SUFFIX:+-$SUFFIX}"
INSTALL_DIR="$BXDECAY0_HOME/install-bxdecay0-$VER${SUFFIX:+-$SUFFIX}"

rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

cmake -S "$REPO_DIR" -B "$BUILD_DIR" -G "$GENERATOR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON \
  -DBXDECAY0_WITH_GEANT4_EXTENSION=ON \
  -DBXDECAY0_INSTALL_DBD_GA_DATA=ON \
  -DGeant4_DIR="$Geant4_DIR" \
  -DCMAKE_PREFIX_PATH="$GEANT4_BASE;/opt/homebrew"





echo
echo "[3/4] Build + test (with retries)"
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

# Tests are optional; don't kill the whole script if they fail unless you want to
echo
if ask_yn "Run ctest now? [Y/n]:" "Y"; then
  (cd "$BUILD_DIR" && ctest --output-on-failure) || {
    echo "ctest failed. Fix tests or rerun with tests skipped."
    exit 1
  }
fi

echo
echo "[4/4] Install"
cmake --install "$BUILD_DIR"
echo "Installed to $INSTALL_DIR"
echo

# -----------------------------
# Update ~/.zshrc
# -----------------------------
if [[ "$DO_UPDATE_ZSHRC" == "yes" ]]; then
  ZSHRC="$HOME/.zshrc"
  [[ -f "$ZSHRC" ]] || : > "$ZSHRC"

  tmp="$(mktemp)"
  cat "$ZSHRC" > "$tmp"

  # Remove any existing BXDECAY0 block previously added (between markers)
  # If no markers, this is a no-op.
  sed -i '' -e '/^# ╭───────────────────────────────╮[[:space:]]*$/,/^# ╰───────────────────────────────╯[[:space:]]*$/{
/^# ╭───────────────────────────────╮[[:space:]]*$/,/^# ╰───────────────────────────────╯[[:space:]]*$/d
}' "$tmp" 2>/dev/null || true

  cat >> "$tmp" <<EOF

# ╭───────────────────────────────╮
# │     🧬 BxDecay0               │
# ╰───────────────────────────────╯
export BXDECAY0_HOME="$BXDECAY0_HOME"
export BXDECAY0_PREFIX="$INSTALL_DIR"
export PKG_CONFIG_PATH="\$BXDECAY0_PREFIX/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
EOF

  mv "$tmp" "$ZSHRC"
  echo "~/.zshrc updated."
  echo "NOTE: To apply in your current shell, run: source ~/.zshrc"
fi

echo "DONE: bxdecay0 ($VER) ready"