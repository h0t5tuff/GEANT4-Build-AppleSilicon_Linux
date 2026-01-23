# LEGEND Simulation Build Scripts

Reproducible build scripts for the **LEGEND collaboration** simulation software stack:
**HDF5 → Geant4 → BxDecay0 → remage**.

These scripts provide a clean, from-source build chain with correct **thread safety**, **CMake discoverability**, and **ABI consistency**, targeting macOS (Apple Silicon) and avoiding conflicts with system or Homebrew installations.

---

## Motivation

Geant4- and remage-based simulations critically depend on a **thread-safe, C++-enabled HDF5** build and a consistent dependency chain. In practice, mixing system or Homebrew libraries often leads to silent killers.  
I developed these scripts to give collaborators a **single, reliable way to build the full simulation stack**, ensuring that Geant4 and remage work properly, with behavior that is reproducible across machines and over time.

---

## Dependency stack

┌─────────────────────────────┐
│ remage │
│ (LEGEND simulation layer) │
└───────────────┬─────────────┘
│
▼
┌─────────────────────────────┐
│ BxDecay0 │
│ (external generator) │
└───────────────┬─────────────┘
│
▼
┌─────────────────────────────┐
│ Geant4 │
│ (MT, GDML, HDF5, ROOT I/O) │
└───────────────┬─────────────┘
│
▼
┌─────────────────────────────┐
│ HDF5 │
│ (1.x, C++, thread-safe) │
└───────────────┬─────────────┘
│
▼
┌─────────────────────────────┐
│ ROOT │
│ (via Homebrew) │
└───────────────┬─────────────┘
│
▼
┌─────────────────────────────┐
│ system / Homebrew │
│ (clang, CMake, pkg-config) │
└─────────────────────────────┘

---

## Provided scripts

### `build-hdf5.sh`

Builds the latest **HDF5 1.x** release with:

- Thread safety **ON**
- C++ library **ON**
- HL / Fortran / Java / tests **OFF**
- Patched `h5cc` supporting `-show` (required by CMake)
- Valid `HDF5Config.cmake` for `find_package(HDF5)`

This is the **foundation** of the stack.

---

### `build-geant4.sh`

Builds the latest stable **Geant4** with:

- Multithreading
- GDML support
- OpenGL + Qt visualization
- HDF5 analysis enabled
- Automatic dataset download
- Retry logic for flaky network downloads

Includes a link-time test verifying:

- `libG4analysis`
- correct linkage to the intended `libhdf5`

---

### `build-bxdecay0.sh`

Builds **BxDecay0** with Geant4 support for double-beta decay simulations.

---

### `build-remage.sh`

Builds **remage** against the locally built stack:

- Uses `GEANT4_BASE` explicitly
- Forces CMake to use the correct HDF5 installation
- Verifies HDF5 thread safety during configuration
- Supports tagged releases or development builds

---

## Usage order (important)

```bash
./build-hdf5.sh
./build-geant4.sh
./build-bxdecay0.sh
./build-remage.sh

Notes
	•	Tested on macOS (arm64).
	•	Designed for LEGEND low-background physics simulations.
	•	Focused on correctness, reproducibility, and transparent dependency resolution.
	•	Suitable both for local development and long-term production environments.
```
