1. move the two scripts in this repo to your home directory.

2. open .zshrc/.bashrc file in your home directory and comment out any Geant4 related lines.

3. now excute the build/uninstall script:

>chmod +x file_name.sh

4. finally run the build/uninstall script:

>./file_name.sh

5. Discard of this README.md












## Build an example

Copy an example from src to my geant4 folder

>cd geant4
>
>cp -R /Users/tensor/geant4/src/examples/basic/B1 ~/geant4/B1_Tensor
>
>cd ~/geant4examples/B1_tensor

Build

>mkdir build && cd build

on mac

>// rm -rf build && mkdir build && cd build // if you wanna rebuild
>
>cmake .. -DCMAKE_BUILD_TYPE=Release -DGeant4_DIR="$HOME/geant4/install/lib/cmake/Geant4" -DCMAKE_PREFIX_PATH="$(brew --prefix root):$HOME/geant4/install/lib/cmake/Geant4"
>
>// make clean //if you wanna remake
>
>make -j$(sysctl -n hw.ncpu)



Check what was enabled during build
>cat /Users/tensor/geant4/build/CMakeCache.txt | grep GEANT4_USE

Confirm Geant4 Build Has Qt, OpenGL, GDML, CADMesh, etc
>$HOME/geant4/install/bin/geant4-config --features

run Interactive session
>./exampleB1

In Geant4 prompt
>/control/execute vis.mac
