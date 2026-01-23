-------------this_was_my_method_before_homebrew_created_a_native_arm64_bottle_for_root_late2025------------
#DEPENDENCIES
 ## amd64 architecture: I found that putting <arch -x86_64 > before the official homebrew install command gets the job done ;)
brew install python wget git make xerces-c cmake ninja pkgconf
brew install qt@5 libx11 
             --cask xquartz
brew install cfitsio davix fftw freetype ftgl gcc giflib gl2ps glew \
             graphviz gsl jpeg-turbo libpng libtiff lz4 mariadb-connector-c \
             nlohmann-json numpy openblas openssl pcre pcre2 python sqlite \
             tbb xrootd xxhash xz zstd
# BUILD:
mkdir ROOT && cd ROOT
git clone https://github.com/root-project/root.git
cd root
git checkout v6-36-00
cd ..
rm -rf build && mkdir build && cd build
env CFLAGS="-I/usr/local/include" \
    CXXFLAGS="-I/usr/local/include" \
    LDFLAGS="-L/usr/local/lib" \
    arch -x86_64 cmake .. \
      -DCMAKE_INSTALL_PREFIX="$ROOT_INSTALL" \
      -Dx11=ON \
      -Dopengl=ON \
      -Droofit=ON \
      -Dtmva=ON \
      -DCMAKE_CXX_STANDARD=17
grep ZSTD CMakeCache.txt || echo "zstd not detected properly."
arch -x86_64 make -j$(sysctl -n hw.logicalcpu)
arch -x86_64 make install

