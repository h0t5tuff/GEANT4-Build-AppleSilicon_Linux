--------------------------------ROOT--------------------------------
——Bacon2Data———
#Build:
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
----BACONMONITOR-----
On mac:
  xhost +SI:localuser:root 
On daq (via ssh):
  ln -s /home/bacon/BaconMonitor/BaconMonitor2_tensor.py /home/Tensor/BaconMonitor2_tensor.py
  sudo visudo
	Tensor ALL=(ALL) NOPASSWD: SETENV: /usr/bin/python3 /home/Tensor/BaconMonitor2_tensor.py







--------------------------------GEANT4--------------------------------
# BaconCalibrationSimulation:
Debugging Log: Getting `BACONCalibrationSimulation` (Geant4) Running
Here I document a successful problem-solving session of Alex's sim, BACONCalibrationSimulation. Including:
header scoping fixes,
STL file path handling,
env-based root file path flexibility
final sim launch.
1. Geant4 Header Scoping Error, `G4Track` Undefined
Issue: unknown type name ‘G4Track’
That's because recent Geant4 versions require explicit inclusion of class headers. so any forward declarations or umbrella includes are no longer sufficient.
Fix:
I explicitly forward declare in the header `HistoManager.hh` then I include the real header in `HistoManager.cc`
```cpp
class G4Track;
and
#include "G4Track.hh"
```
2. STL File Rejection – CADMesh Expects ASCII Format
Issue: CADMesh has error around line 1 that the STL file start with 'solid'
Diagnosing this, I initially thought the stl file is binary instead of ASCII , or maybe that path is incorrect.
My Sanity Checks :)
- Check file header:
```bash
head -n 5 source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL | cat -vet
```
- Check file tail:
```bash
tail -n 10 source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL | cat -vet
```
- now I check for non-printable (binary) rubbish:
```bash
grep -a -o '[^[:print:][:space:]]' source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL | head
```
there was nothing weird coming out so I conclude that the STL file was indeed valid and in ASCII format! 
therefore the error persisted because the file path was incorrect.
The file path does not exist at runtime, so CADMesh is reading a non-existent or empty file and (correctly) errors out with the “STL files start with ‘solid’” message
ls -l ../BACONCalibrationSimulation/STLFiles/source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL
ls: ../BACONCalibrationSimulation/STLFiles/source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL: No such file or directory
Fix: here I confirm correct path:
```bash
ls -l ../STLFiles/source_holder_assembly_axes_aligned_simplified_coursemeshcombined_v20250521.STL
```
then I updated path in code `DetectorConstruction.cc`: line199 before  
 auto BasePlateMesh = CADMesh::TessellatedMesh::FromSTL(fSourceHolderFilePath);
I created a folder named BACONCalibrationSimulation with a symlink to STL files:

cd BACONCalibrationSimulation
mkdir -p BACONCalibrationSimulation
ln -s ../STLFiles BACONCalibrationSimulation/STLFiles
Then I went and adjusted the root files path in all macros so we get the root files
also removed anything saying "shard" in CMakelists.txt since there is no "shared" folder


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












--------------------------------REMAGE--------------------------------

rm -f *.root 
rm -f *.hdf5
rm -rf build
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -Dremage_DIR="$REMAGE_PREFIX/lib/cmake/remage" \
  -DCMAKE_PREFIX_PATH="$REMAGE_PREFIX;$BXDECAY0_PREFIX;$GEANT4_BASE;/opt/homebrew"
cmake --build build -j"$(sysctl -n hw.ncpu)"
#run:
ex1
UI-mode: ./build/<sim> ---> /control/execute <mac> 
batch-mode: ./build/<sim> <mac>

ex2 & 3
UI-mode: ./build/<sim> -i <mac> 
batch-mode: ./build/<sim> <mac>

# examples/01-gdml:
  ##rewrote main.cc to have UI and rewrote vis macros to work##
  # to prove you can ingest a realistic detector-stand geometry via GDML and run particles through it.
            #Geometry hierarchy:  main.gdml composes modules (cryostat, holder, wrap, source) into a world.
	      #Materials + overlaps: duplicate material names warning; tiny overlaps cause tracking artifacts.
	 	#Vertex confinement efficiency: geometric acceptance of defined source volume.
  # Run run.mac (batch) and confirm stablity / Switch generator in macros (GPS) between gammas/electrons/ions and observe interaction signatures / Add a thin dead layer or change material and watch gross rate changes (systematics intuition).



# examples/02-hpge:
  #*created script analyze_hpge_hdf5.ipynb*# 
  #*The geometry + physics + generator parts in run.mac are fine.*#
  #*The vis macros do their own /run/initialize and then set up visualization + (for vis-traj.mac) define a GPS source and run /run/beamOn 100.*#
  # to define an HPGe detector (geometry + sensitive detector + scoring) and learn which quantities can output
		#Energy deposition in active Ge (spectrum shape)
		#Single-site vs multi-site behavior (Compton vs photoelectric)
		#How geometry changes peak efficiency
  # this is the core of LEGEND-style “what deposits near Q_ββ” thinking.



# examples/03-optics: 
  # LAr veto, Optical photons and scintillation/absorption.
    # Optical photon tracking + PMT/SiPM or optical surfaces / Storing optical observables into ROOT
    # How optical transport depends on surface definitions (polish, reflectivity).
    # Why optical simulation is expensive and requires careful reduction/observables.
  # LEGEND uses LAr veto concepts; optical response matters when you interpret veto performance, light yield, and veto coincidence rates, this is the conceptual bridge to LEGEND LAr veto light collection and surface modeling



# examples/04-cosmogenics:
  # Cosmogenic production/activation and/or cosmogenic event generation.
      # Activate isotopes, or simulate cosmogenic-induced decays in/near HPGe detectors.
      # Which isotopes dominate in Ge for your exposure assumptions
      # How delayed backgrounds arise from activation products.
  # Cosmogenic isotopes drive background models.




# examples/05-MUSUN: 
  # to use an external muon generator input (MUSUN CSV) to drive the simulation for u nderground muon backgrounds.
	# muons are sampled from a precomputed distribution (energy, angle, position)
	# remage generator reads and injects muons accordingly
	# Muon-induced backgrounds are geometry-dependent and rare but high-impact.
	# external muon spectrum → event injection → secondaries → detector response.
      # Secondary neutrons and gammas as a function of material around detector
	# modeling muon flux and angular distribution is essential for background budgets.
  # cosmogenic + muon-induced backgrounds and veto strategies.



# examples/06-NeutronCapture:
  # to validate neutron capture models and gamma cascades in materials.
	# simulating n-capture
	# recording which isotopes captured
	# recording gamma cascade properties
	# Capture gamma cascades are a major background mechanism.
	# How to implement a custom output scheme for specific physics questions (isotope accounting).
	# Neutron capture in materials (Cu, SS, Ar, etc.) creates gamma lines and Compton continua near ROI.
  # material choice + neutron moderation strategy





# examples/07-my-legend-study:





remage-systematically:
Step 1 — Geometry sanity + reproducibility
	•	Always run a batch macro first (no UI) and confirm:
	    •	overlap check is clean enough for tracking
	    •	event rate is stable
	•	Fix geometry before physics. Otherwise you chase ghosts.
Step 2 — Single-process intuition (HPGe)
    Run monoenergetic gammas and electrons and build intuition:
    	•	Photopeak vs Compton continuum (gamma)
	    •	Bremsstrahlung + MCS + range (electron)
	    •	Sensitivity to dead layer / holder material
Step 3 — Add realistic sources (decays, chains)
	•	Use BxDecay0 / built-in decay machinery where appropriate
	•	Compare “truth-level emission” vs “detected deposition”
Step 4 — Add correlated handles (tracks, timing, veto)
	•	Turn on track output schemes where available
	•	For LAr optics: treat “light yield → veto” as a physics handle

LEGEND-200:
  What backgrounds survive all cuts near Q_ββ?
    In simulation lingo:
	  •	Generate backgrounds in the correct place (materials and surfaces).
	  •	Transport them through the real geometry.
	  •	Record observables used in analysis: energy in detectors, multiplicity, distances, timing/veto flags.
  What is the signal efficiency?
	  •	Generate 0νββ decays in active volume.
	  •	Track energy depositions and topology proxies (multi-site vs single-site).
	  •	Include detector effects later (resolution, thresholds).











