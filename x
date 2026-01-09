-------APPLESILICON----------
# DEPENDENCIES:
base tools:
brew install python wget git make xerces-c
Build utilities:
brew install cmake ninja pkgconf
graphics requirements:
brew install qt@5 libx11
brew install --cask xquartz
root stuff:
brew install cfitsio davix fftw freetype ftgl gcc giflib gl2ps glew \
             graphviz gsl jpeg-turbo libpng libtiff lz4 mariadb-connector-c \
             nlohmann-json numpy openblas openssl pcre pcre2 python sqlite \
             tbb xrootd xxhash xz zstd
geant4 stuff:
brew install clhep expat jpeg libxi libxmu open-mpi
(make sure to build HDF5 first, see below.)
# BUILD:
mkdir GEANT4 && cd GEANT4
git clone https://github.com/Geant4/geant4.git geant4
cd geant4
git fetch --tags 
git checkout geant4-11.4-release
rm -rf build-11.4 && mkdir build-11.4 && cd build-11.4
cmake ../geant4 \
  -DCMAKE_INSTALL_PREFIX=../install-11.4 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGEANT4_BUILD_MULTITHREADED=ON \
  -DGEANT4_INSTALL_DATA=ON \
  -DGEANT4_INSTALL_EXAMPLES=ON \
  -DGEANT4_USE_SYSTEM_EXPAT=ON \
  -DGEANT4_USE_GDML=ON \
  -DGEANT4_USE_QT=ON \
  -DGEANT4_USE_OPENGL=ON \
  -DGEANT4_USE_HDF5=ON \
  -DHDF5_INCLUDE_DIRS="$HDF5_ROOT/include" \
  -DHDF5_C_INCLUDE_DIR="$HDF5_ROOT/include" \
  -DHDF5_HL_INCLUDE_DIR="$HDF5_ROOT/include" \
  -DHDF5_LIBRARIES="$HDF5_ROOT/lib/libhdf5.dylib;$HDF5_ROOT/lib/libhdf5_hl.dylib" \
  -DHDF5_C_LIBRARIES="$HDF5_ROOT/lib/libhdf5.dylib" \
  -DHDF5_HL_LIBRARIES="$HDF5_ROOT/lib/libhdf5_hl.dylib" \
  -DCMAKE_PREFIX_PATH="/opt/homebrew"
make -j"$(sysctl -n hw.ncpu)"
make install
(-DHDF5_DIR="$HDF5_ROOT/cmake" did not work, so I set HDF5_LIBRARIES (and friends) explicitly... nightmare)

———————LINUX—————————
DEPENDENCIES:
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
BUILD:
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

—————————EXAMPLES———————
cd ~/GEANT4/geant4/examples/basic/B1
rm -rf build && mkdir build && cd build
(on mac)
cmake .. 
  -DGeant4_DIR="$Geant4_DIR"
make -j"$(sysctl -n hw.ncpu)"
(on linux)
cmake .. 
  -DCMAKE_BUILD_TYPE=Release 
  -DGeant4_DIR=/home/bacon/geant4/geant4_install/lib/cmake/Geant4 
  -DCMAKE_PREFIX_PATH="/usr/local/Cellar/root/6.36.01;/home/bacon/geant4/geant4_install/lib/Geant4-11.3.1/cmake"
make -j$(nproc)

UI mode: ./<sim> ---> /control/execute <mac> 
batch mode: ./<sim> -m <mac>









--------------HDF5 (needed for REMAGE)-----------
mkdir HDF5 && cd HDF5
git clone https://github.com/HDFGroup/hdf5.git
cd hdf5
git checkout hdf5-1_14_3
rm -rf build install && mkdir build install && cd build
cmake ../hdf5 \
  -DCMAKE_INSTALL_PREFIX=../install \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DHDF5_ENABLE_THREADSAFE=ON \
  -DHDF5_BUILD_HL_LIB=ON \
  -DALLOW_UNSUPPORTED=ON \
  -DHDF5_BUILD_CPP_LIB=OFF \
  -DHDF5_BUILD_FORTRAN=OFF \
  -DHDF5_BUILD_JAVA=OFF \
  -DBUILD_TESTING=OFF
cmake --build . -j"$(sysctl -n hw.ncpu)"
cmake --install .
