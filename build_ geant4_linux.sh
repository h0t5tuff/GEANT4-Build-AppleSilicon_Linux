#!/bin/bash

# failsafe
set -euo pipefail

# === Required system packages ===
echo "📦 Installing required dependencies for Geant4..."
sudo apt update
sudo apt install -y \
  cmake g++ \
  qtbase5-dev libqt5opengl5-dev qtchooser qt5-qmake qtbase5-dev-tools \
  libxmu-dev libxi-dev \
  libglu1-mesa-dev freeglut3-dev mesa-common-dev \
  libxerces-c-dev libexpat1-dev \
  libhdf5-dev libsqlite3-dev \
  libclhep-dev \
  libopenmpi-dev \
  zlib1g-dev libssl-dev \
  curl wget unzip

# === Define Geant4 source and build directories ===
G4SRC=~/geant4-v11.3.1
G4BUILD=~/geant4/build
G4INSTALL=~/geant4/geant4_install

echo "📁 Creating build and install directories..."
mkdir -p "$G4BUILD" "$G4INSTALL"
cd "$G4BUILD" || { echo "❌ Failed to enter build directory."; exit 1; }

# === Configure with CMake ===
echo "🔍 Configuring Geant4 with CMake..."
cmake "$G4SRC" \
    -DCMAKE_INSTALL_PREFIX="$G4INSTALL" \
    -DGEANT4_BUILD_MULTITHREADED=ON \
    -DGEANT4_INSTALL_DATA=ON \
    -DGEANT4_USE_QT=ON \
    -DGEANT4_USE_OPENGL_X11=ON
    -DGEANT4_USE_GDML=ON \
    -DGEANT4_USE_SYSTEM_CLHEP=ON

# === Build and install ===
echo "🛠️ Building Geant4 with $(nproc) threads..."
make -j"$(nproc)"

echo "📦 Installing to $G4INSTALL..."
make install

# === Add to .bashrc if not already added ===
GEANT4_ENV_LINE="source $G4INSTALL/bin/geant4.sh"
if ! grep -Fxq "$GEANT4_ENV_LINE" ~/.bashrc; then
    echo "$GEANT4_ENV_LINE" >> ~/.bashrc
    echo "🔁 Appended Geant4 environment source line to ~/.bashrc"
fi

# === Source Geant4 environment ===
source "$G4INSTALL/bin/geant4.sh"

# === Set Data Environment Variables ===
echo "🌐 Setting Geant4 dataset environment variables..."
export GEANT4DIR="$G4INSTALL"
export GEANT4_DATA_DIR="$GEANT4DIR/share/Geant4/data"
export G4ENSDFSTATEDATA="$GEANT4_DATA_DIR/G4ENSDFSTATE.3.0/G4ENSDFSTATE3.0"
export G4NEUTRONHPDATA="$GEANT4_DATA_DIR/G4NDL.4.7.1/G4NDL4.7.1"
export G4LEVELGAMMADATA="$GEANT4_DATA_DIR/G4PhotonEvaporation.6.1/G4PhotonEvaporation6.1"
export G4LEDATA="$GEANT4_DATA_DIR/G4EMLOW.8.6.1/G4EMLOW8.6.1"
export G4INCLDATA="$GEANT4_DATA_DIR/G4INCL.1.1/G4INCL1.1"
export G4ABLADATA="$GEANT4_DATA_DIR/G4ABLA.3.3/G4ABLA3.3"
export G4PARTICLEXSDATA="$GEANT4_DATA_DIR/G4PARTICLEXS.4.1/G4PARTICLEXS4.1"
export G4PIIDATA="$GEANT4_DATA_DIR/G4PII.1.3/G4PII1.3"
export G4RADIOACTIVEDATA="$GEANT4_DATA_DIR/G4RadioactiveDecay.6.1.2/G4RadioactiveDecay6.1.2"
export G4REALSURFACEDATA="$GEANT4_DATA_DIR/G4RealSurface.2.2/G4RealSurface2.2"
export G4SAIDXSDATA="$GEANT4_DATA_DIR/G4SAIDDATA.2.0/G4SAIDDATA2.0"
export G4CHANNELINGDATA="$GEANT4_DATA_DIR/G4CHANNELING.1.0/G4CHANNELING1.0"

echo "✅ Geant4 build and setup complete!"