#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#  1) preflight: Geant4 + git-lfs
#  2) clone/update bxdecay0
#  3) configure + build (with retries) + test + install
#  4) append BXDECAY0 env block to ~/.zshrc 
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

# -----------------------------
# Preflight
# -----------------------------
echo "Preflight: Geant4"
: "${GEANT4_BASE:?ERROR: export GEANT4_BASE first}"
Geant4_DIR="${Geant4_DIR:-$GEANT4_BASE/lib/cmake/Geant4}"
[[ -f "$Geant4_DIR/Geant4Config.cmake" ]] || { echo "ERROR: Geant4Config.cmake not found: $Geant4_DIR"; exit 1; }
echo "GEANT4_BASE=$GEANT4_BASE"
echo "Geant4_DIR =$Geant4_DIR"
echo

echo "Preflight: git-lfs"
if ! command -v git-lfs >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install git-lfs
  else
    echo "ERROR: git-lfs required"
    exit 1
  fi
fi
git lfs install >/dev/null 2>&1 || true
echo

# -----------------------------
# User choices
# -----------------------------
BXDECAY0_HOME="${BXDECAY0_HOME:-$HOME/BXDECAY0}"

if ask_yn "Create workdir '$BXDECAY0_HOME'? [Y/n]:" "Y"; then
  mkdir -p "$BXDECAY0_HOME"
fi

read -r -p "Numeric suffix for build/install dirs (digits or empty): " SUFFIX || true
[[ -z "$SUFFIX" || "$SUFFIX" =~ ^[0-9]+$ ]] || { echo "Suffix must be digits only"; exit 1; }

ZSHRC="$HOME/.zshrc"
DO_UPDATE_ZSHRC="no"
read -r -p "After install, update ~/.zshrc GEANT4_BASE to this install? [Y/n]: " ans
ans="${ans:-Y}"
if [[ "$ans" =~ ^[Yy]$ ]]; then
  DO_UPDATE_ZSHRC="yes"
fi

# -----------------------------
# Clone/update
# -----------------------------
echo "[1/4] Clone/update bxdecay0"
REPO_DIR="$BXDECAY0_HOME/bxdecay0"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone https://github.com/BxCppDev/bxdecay0.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch --tags --prune origin

# Determine default branch robustly
default_branch="$(
  git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's|^origin/||' || true
)"

if [[ -z "${default_branch:-}" ]]; then
  if git show-ref --verify --quiet refs/remotes/origin/master; then
    default_branch="master"
  elif git show-ref --verify --quiet refs/remotes/origin/main; then
    default_branch="main"
  else
    # last resort: pick first remote branch
    default_branch="$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed 's|^origin/||' | grep -v '^HEAD$' | head -n 1 || true)"
  fi
fi

[[ -n "${default_branch:-}" ]] || { echo "ERROR: could not determine default branch"; exit 1; }

echo "Default branch: $default_branch"
git switch "$default_branch"
git pull --ff-only || true

git lfs pull
cd "$BXDECAY0_HOME"
echo

# -----------------------------
# Configure
# -----------------------------
echo "[2/4] Configure"
BUILD_DIR="$BXDECAY0_HOME/build${SUFFIX:+-$SUFFIX}"
INSTALL_DIR="$BXDECAY0_HOME/install${SUFFIX:+-$SUFFIX}"

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
  -DBUILD_SHARED_LIBS=ON \
  -DBXDECAY0_WITH_GEANT4_EXTENSION=ON \
  -DBXDECAY0_INSTALL_DBD_GA_DATA=ON \
  -DGeant4_DIR="$Geant4_DIR" \
  -DCMAKE_PREFIX_PATH="$GEANT4_BASE;/opt/homebrew"

# -----------------------------
# Build + test (always)
# -----------------------------
echo "[3/4] Build + test"
JOBS="$(sysctl -n hw.ncpu)"
MAX_RETRY=5
TRY=1

while true; do
  set +e
  cmake --build "$BUILD_DIR" -j"$JOBS"
  RC=$?
  set -e
  [[ $RC -eq 0 ]] && break
  [[ $TRY -ge $MAX_RETRY ]] && { echo "Build failed"; exit $RC; }
  echo "Retry $TRY/$MAX_RETRY..."
  TRY=$((TRY+1))
  sleep 10
done

ctest --test-dir "$BUILD_DIR" --output-on-failure

# -----------------------------
# Install
# -----------------------------
echo "[4/4] Install"
cmake --install "$BUILD_DIR"
echo "Installed to $INSTALL_DIR"
echo

# -----------------------------
# Update ~/.zshrc
# -----------------------------
if [[ "${DO_UPDATE_ZSHRC:-no}" == "yes" ]]; then
  ZSHRC="${ZSHRC:-$HOME/.zshrc}"

  [[ -f "$ZSHRC" ]] || : > "$ZSHRC"

  echo "Updating existing BXDECAY0_PREFIX in ~/.zshrc -> $INSTALL_DIR"

  tmp="$(mktemp)"
  if grep -qE '^[[:space:]]*export[[:space:]]+BXDECAY0_PREFIX=' "$ZSHRC"; then
    sed -E "s|^[[:space:]]*export[[:space:]]+BXDECAY0_PREFIX=.*$|export BXDECAY0_PREFIX=\"$INSTALL_DIR\"|g" \
      "$ZSHRC" > "$tmp"
  else
    cat "$ZSHRC" > "$tmp"
    cat >> "$tmp" <<EOF

# ╭───────────────────────────────╮
# │     🧬 BxDecay0               │
# ╰───────────────────────────────╯
export BXDECAY0_HOME="$BXDECAY0_HOME"
export BXDECAY0_PREFIX="$INSTALL_DIR"
export PKG_CONFIG_PATH="\$BXDECAY0_PREFIX/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
EOF
  fi
  mv "$tmp" "$ZSHRC"
  echo "~/.zshrc updated."

export BXDECAY0_HOME="$BXDECAY0_HOME"
export BXDECAY0_PREFIX="$INSTALL_DIR"
fi










echo
echo "DONE: BxDecay0 ready"