# BaconCalibrationSimulation:
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_GEANT4_UIVIS=ON \
  -DCMAKE_PREFIX_PATH="$(geant4-config --prefix);$ROOT_DIR" 
cmake --build build -j"$(sysctl -n hw.ncpu)"

# underground_physics  
  shielding optimization and neutron moderation logic. Add a simple slab of material in DetectorConstruction. Compare rates/energy deposition downstream
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_GEANT4_UIVIS=ON \
    -DDMXENV_GPS_USE=ON \
    -DCMAKE_PREFIX_PATH="$(geant4-config --prefix);$ROOT_DIR" 
cmake --build build -j"$(sysctl -n hw.ncpu)"

# lAr_calorimeter       
  LAr veto light collection sensitivity studies. Change scintillation yield and absorption length. Measure detected photoelectrons vs distance/geometry

# xray_fluorescence 
  Pick a material. Fire gammas/electrons at a surface. Verify the fluorescence X-ray lines appear in the output energy spectrum background line ID and detector material response sanity checks.

# IAEAphsp  
  realistic source generation, reusing precomputed distributions. Phase-space inputs. reproducible source modeling patterns.

# human_phantom
  teaches geometry organization and run control.


















———————LINUX—————————
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
# ex:
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DGeant4_DIR=/home/bacon/geant4/geant4_install/lib/cmake/Geant4 \
  -DCMAKE_PREFIX_PATH="/usr/local/Cellar/root/6.36.01;/home/bacon/geant4/geant4_install/lib/Geant4-11.3.1/cmake"
make -j$(nproc)



