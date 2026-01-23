

------------geant4---------------

# DEPENDENCIES:
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
# BUILD:
G4SRC=~/geant4-v11.3.1
G4BUILD=~/geant4/build
G4INSTALL=~/geant4/geant4_install
mkdir -p "$G4BUILD" "$G4INSTALL"
cd "$G4BUILD"
cmake "$G4SRC" \
    -DCMAKE_INSTALL_PREFIX="$G4INSTALL" \
    -DGEANT4_BUILD_MULTITHREADED=ON \
    -DGEANT4_INSTALL_DATA=ON \
    -DGEANT4_USE_QT=ON \
    -DGEANT4_USE_OPENGL_X11=ON
    -DGEANT4_USE_GDML=ON \
    -DGEANT4_USE_SYSTEM_CLHEP=ON
make -j"$(nproc)"
make install
# example:
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DGeant4_DIR=/home/bacon/geant4/geant4_install/lib/cmake/Geant4 \
  -DCMAKE_PREFIX_PATH="/usr/local/Cellar/root/6.36.01;/home/bacon/geant4/geant4_install/lib/Geant4-11.3.1/cmake"
make -j$(nproc)



