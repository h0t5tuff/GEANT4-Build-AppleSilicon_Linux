# APPLESILICON


DEPENDENCIES:

echo "base tools"
brew install python wget git make xerces-c
echo "Build utilities"
brew install cmake ninja pkgconf
echo "graphics requirements"
brew install qt@5 libx11
brew install --cask xquartz
echo "root stuff"
brew install cfitsio davix fftw freetype ftgl gcc giflib gl2ps glew \
             graphviz gsl jpeg-turbo libpng libtiff lz4 mariadb-connector-c \
             nlohmann-json numpy openblas openssl pcre pcre2 python sqlite \
             tbb xrootd xxhash xz zstd
echo "geant4 stuff"
brew install clhep expat jpeg libxi libxmu open-mpi

# Update and cleanup
brew update && brew upgrade && brew autoremove && brew cleanup && brew doctor
——————————————————
BUILD:

echo "📁 Creating Geant4 directory tree..."
mkdir -p ~/geant4/src ~/geant4/build ~/geant4/install
cd ~/geant4/src

echo "🔁 Cloning Geant4 v11.3.2..."
git clone --branch v11.3.2 --depth 1 https://gitlab.cern.ch/geant4/geant4.git .
git checkout tags/v11.3.2 -b geant4-11.3.2

echo "⚙️ Configuring CMake build..."
cd ~/geant4/build
cmake ../src \
  -DCMAKE_INSTALL_PREFIX=../install \
  -DGEANT4_BUILD_MULTITHREADED=ON \
  -DGEANT4_USE_OPENGL_X11=ON \
  -DGEANT4_USE_QT=ON \
  -DGEANT4_USE_RAYTRACER_X11=ON \
  -DGEANT4_USE_GDML=ON \
  -DGEANT4_INSTALL_DATA=ON \
  -DGEANT4_USE_SYSTEM_CLHEP=ON \
  -DQt5_DIR="$(brew --prefix qt@5)/lib/cmake/Qt5"
echo "🛠️ Building Geant4 using $(sysctl -n hw.ncpu) threads..."
make -j"$(sysctl -n hw.ncpu)"
echo "📥 Installing to ~/geant4/install..."
make install


export G4SRC=~/GEANT4/src
export G4BUILD=~/GEANT4/build-11.4-HDF5-xMTx
export G4INSTALL=~/GEANT4/install-11.4-HDF5-xMTx

rm -rf "$G4BUILD"
mkdir -p "$G4BUILD" && cd "$G4BUILD"

cmake "$G4SRC" \
  -DCMAKE_INSTALL_PREFIX="$G4INSTALL" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGEANT4_BUILD_MULTITHREADED=OFF \
  -DGEANT4_INSTALL_DATA=ON \
  -DGEANT4_INSTALL_EXAMPLES=ON \
  -DGEANT4_USE_SYSTEM_EXPAT=ON \
  -DGEANT4_USE_GDML=ON \
  -DGEANT4_USE_QT=ON \
  -DGEANT4_USE_OPENGL=ON \
  -DCMAKE_PREFIX_PATH="/opt/homebrew" \
  -DGEANT4_USE_HDF5=ON \
  -DHDF5_ROOT="$(brew --prefix hdf5)" 
make -j"$(sysctl -n hw.ncpu)"
make install
————————————————
.zshrc:

————————————————
EXAMPLE:

cd ~/GEANT4/src/examples
rm -rf build && mkdir build && cd build

cmake .. -DGeant4_DIR="$Geant4_DIR"
make -j"$(sysctl -n hw.ncpu)"

./<sim>
/control/execute <mac>

./<sim> -m <mac>

Check what was enabled during build
cat /Users/tensor/geant4/build/CMakeCache.txt | grep GEANT4_USE






















# LINUX


DEPENDENCIES:

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
————————————————
BUILD:

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
————————————————
.bashrc:

GEANT4_ENV_LINE="source $G4INSTALL/bin/geant4.sh"
if ! grep -Fxq "$GEANT4_ENV_LINE" ~/.bashrc; then
    echo "$GEANT4_ENV_LINE" >> ~/.bashrc
    echo "🔁 Appended Geant4 environment source line to ~/.bashrc"
fi
source "$G4INSTALL/bin/geant4.sh"
————————————————
# EXAMPLE:

cd geant4
cp -R /Users/tensor/geant4/src/examples/basic/B1 ~/geant4/B1_Tensor
cd ~/geant4examples/B1_tensor
mkdir build && cd build

cmake .. -DCMAKE_BUILD_TYPE=Release -DGeant4_DIR=/home/bacon/geant4/geant4_install/lib/cmake/Geant4 -DCMAKE_PREFIX_PATH="/usr/local/Cellar/root/6.36.01;/home/bacon/geant4/geant4_install/lib/Geant4-11.3.1/cmake"
make -j$(nproc)

Check what was enabled during build
cat /Users/tensor/geant4/build/CMakeCache.txt | grep GEANT4_USE

Confirm Geant4 Build Has Qt, OpenGL, GDML, CADMesh, etc
$HOME/geant4/install/bin/geant4-config --features

run Interactive session
./exampleB1

In Geant4 prompt
/control/execute vis.mac
