1. move the two scripts in this repo to your home directory.

2. open .zshrc/.bashrc file in your home directory and comment out any Geant4 related lines.

3. now excute the build/uninstall script:

>chmod +x file_name.sh

4. finally run the build/uninstall script:

>./file_name.sh

5. Discard of this README.md





>export G4SRC=~/GEANT4/src
>export G4BUILD=~/GEANT4/build-11.4-HDF5-xMTx
>export G4INSTALL=~/GEANT4/install-11.4-HDF5-xMTx

>rm -rf "$G4BUILD"
>
>mkdir -p "$G4BUILD"
>
>cd "$G4BUILD"
>
>cmake "$G4SRC" \
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
>
>make -j"$(sysctl -n hw.ncpu)"
>
>make install








## Build an example

>cd ~/GEANT4/src/examples
>
>rm -rf build
>
>mkdir build && cd build
>
>cmake .. -DGeant4_DIR="$Geant4_DIR"
>
>make -j"$(sysctl -n hw.ncpu)"
>
>./<sim>
>/control/execute <mac>
>
>./<sim> -m <mac>


Check what was enabled during build
>cat /Users/tensor/geant4/build/CMakeCache.txt | grep GEANT4_USE



