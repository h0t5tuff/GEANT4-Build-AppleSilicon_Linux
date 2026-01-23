---------------DEPENDENCY---------
# BxDecay0
mkdir -p BXDECAY0 && cd BXDECAY0 
git clone https://github.com/BxCppDev/bxdecay0.git
cd bxdecay0
git lfs install && git lfs pull
cd ..
rm -rf build 
cmake -S bxdecay0 -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BXDECAY0_PREFIX" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON \
  -DBXDECAY0_WITH_GEANT4_EXTENSION=ON \
  -DBXDECAY0_INSTALL_DBD_GA_DATA=ON \
  -DGeant4_DIR="$Geant4_DIR" \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT:$GEANT4_BASE:/opt/homebrew"
cmake --build build -j"$(sysctl -n hw.ncpu)"
ctest --test-dir build --output-on-failure
cmake --install build
---------------BUILD---------
mkdir -p REMAGE && cd REMAGE
git clone https://github.com/legend-exp/remage.git
rm -rf build
cmake -S remage -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$REMAGE_PREFIX" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DPython3_EXECUTABLE="$Python3_EXECUTABLE" \
  -DBUILD_TESTING=ON \
  -DROOT_DIR="$ROOT_DIR" \
  -DHDF5_DIR="$HDF5_DIR" \
  -DHDF5_ROOT="$HDF5_ROOT" \
  -DGeant4_DIR="$Geant4_DIR" \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
  -DCMAKE_PREFIX_PATH="$HDF5_ROOT;$BXDECAY0_PREFIX;$GEANT4_BASE;/opt/homebrew/opt/root;/opt/homebrew" 
cmake --build build -j"$(sysctl -n hw.ncpu)"
ctest --test-dir build --output-on-failure
cmake --install build
