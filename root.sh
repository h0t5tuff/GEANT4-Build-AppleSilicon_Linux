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

———————EXAMPLE-Bacon2Data———————————————
#Build [Bacon2Data](https://github.com/liebercanis/bacon2Data/tree/runTwo):
  git clone --branch runTwo https://github.com/liebercanis/bacon2Data.git
  cd bacon2Data && git pull
  //git fetch origin && git reset --hard origin/runTwo && git clean -fdx 
#create symlink:
  cd bobj
  (symlink on mac) 
  ln -s /opt/homebrew/opt/root/etc/root/Makefile.arch .     
  (symlink on linux)
  ln -s /snap/root-framework/current/usr/local/etc/Makefile.arch .     
#hard code path if you're not cloning in your home dir:
  cd bobj 
  nano makefile
    INSTALLNAME  :=  $(HOME)/ROOT/bacon2Data/bobj/$(LIBRARY) 
#build:
  make clean; make
  cd ../compiled && make clean; make
#create data dirs and put btbSim and anacg files there:
  #(on mac in compiled)
  mkdir caenData
  mkdir rootData   
  #(on linux in compiled and in bacon2Data)
  ln -s /mnt/Data2/BaconRun5Data/rootData/ rootData
  ln -s /mnt/Data2/BaconRun4Data/caenData/ caenData
  ln -s /home/gold/bacon2Data/compiled/ compiledGold 
  ln -s /home/gold/bacon2Data/bobj/ bobjGold 
# put gains files in bobj then symlink 'em in place to be used by postAna:
  ln -s <gainPeak root file> gainPeakCurrent.root
  ln -s <gainSum root file> gainSumCurrent.root
# Run Excutables:
  (on mac)
  cd compiled
  btbSim <events number>  // then copy root file to /rootData
  anacg <root file from btbSim>   // product root file lives in /caenData
  postAna <etag> <etag> <max entries>  // first change put a summary or post root file in /compiled, then summary or post root file name in gain.C & gainSum.C ln288
  (on linux)
  cd bacon2Data
  nohup ./anacDir.py 00_00_0000 >& anacDir00_00_0000.log &
  top   
--------------BACONMONITOR---------------
On mac:
  xhost +SI:localuser:root 
On daq (via ssh):
  ln -s /home/bacon/BaconMonitor/BaconMonitor2_tensor.py /home/Tensor/BaconMonitor2_tensor.py
  sudo visudo
	Tensor ALL=(ALL) NOPASSWD: SETENV: /usr/bin/python3 /home/Tensor/BaconMonitor2_tensor.py
