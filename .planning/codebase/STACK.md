# Technology Stack

**Analysis Date:** 2026-04-01

## Languages

**Primary:**
- C++ - Core engine, rendering system (Cycles), geometry processing
- C - Foundational systems, GPU drivers, external libraries
- Python 3.13+ - Scripting API, build tools, add-ons system, automation

**Secondary:**
- JavaScript (Vanilla) - Documentation UI and version switcher (`doc/python_api/static/js/version_switch.js`)
- HTML/CSS - Web documentation and API reference pages
- CMake - Build system configuration

## Runtime

**Environment:**
- CMake 3.10+ - Build configuration and compilation management

**Build System:**
- CMake-based build pipeline - Cross-platform compilation for Windows, macOS, Linux
- GNUmakefile - Alternative make-based build system (`GNUmakefile`)
- Batch scripts (Windows) - `make.bat` for Windows builds

**Compiler Requirements:**
- GCC 14.0.0+ or Clang 17.0+ (LLVM) - Linux/Unix builds
- MSVC 2019 (16.9.16+) - Windows builds
- Apple Clang - macOS builds

## Frameworks

**Core:**
- Cycles - Physically-based path tracing render engine

**Python Integration:**
- bpy Module - Python API for Blender scripting and automation

**3D/Graphics:**
- OpenGL - Graphics backend (when enabled with `WITH_OPENGL_BACKEND`)
- Vulkan - Alternative graphics backend (with `WITH_VULKAN_BACKEND`)
- Metal - Apple platform graphics support (Cycles Metal device)

**Physics & Simulation:**
- Bullet Physics Engine - Rigid body dynamics and collision detection
- Mantaflow - Fluid simulation framework (`extern/mantaflow/`)
- Ocean Modifier - Ocean wave simulation

**Build/Development Tools:**
- GTest - Unit testing framework (`extern/gtest/`, `extern/gmock/`)
- Clang-Tidy - Code analysis tool (optional, `WITH_CLANG_TIDY`)

## Key Dependencies

**Critical:**
- NumPy - Python array processing (used by Audaspace and Mantaflow)
- Requests - Python HTTP library (for release tools and API access)

**Rendering & Color Management:**
- OpenColorIO - Color management and LUT support
- OpenImageDenoise (OIDN) - AI-based compositing denoiser
- OpenEXR - High dynamic range image format support
- OpenJPEG - JPEG2000 image support

**GPU Compute:**
- CUDA - NVIDIA GPU compute (optional, `WITH_CYCLES_DEVICE_CUDA`)
- OptiX - NVIDIA ray tracing (optional, `WITH_CYCLES_DEVICE_OPTIX`)
- HIP - AMD GPU compute (optional, `WITH_CYCLES_DEVICE_HIP`)
- oneAPI - Intel GPU compute (optional, `WITH_CYCLES_DEVICE_ONEAPI`)

**Geometry & Topology:**
- GMP - GNU Multiple Precision Arithmetic (exact boolean operations)
- Manifold - Fast robust boolean geometry operations
- OpenSubdiv - Catmull-Clark surface subdivision
- Potrace - Bitmap to vector conversion
- OpenVDB - Volumetric data structures
- NanoVDB - GPU-optimized volumetric data
- Draco - 3D mesh compression
- Quadriflow - Automatic quadrilateral mesh generation

**Media & I/O:**
- FFmpeg - Video and audio codec support
- Alembic - Animation exchange format support
- USD (Universal Scene Description) - Scene interchange format
- MaterialX - Material interchange format
- glTF/tinygltf - glTF 3D model format support
- UFBX - FBX format support
- libsndfile - Audio file I/O
- WebP - Modern image format support

**Audio:**
- Audaspace - Audio processing and playback
- Rubber Band - Time-stretching and pitch-scaling
- FFTW3 - Fast Fourier Transform for audio/simulation effects

**Utilities:**
- xxHash - Fast hashing algorithm (`extern/xxhash/`)
- curve_fit_nd - Spline curve fitting (`extern/curve_fit_nd/`)
- fast_float - Fast float conversion (`extern/fast_float/`)
- wcwidth - Unicode character width (`extern/wcwidth/`)
- rangetree - Range tree data structure (`extern/rangetree/`)
- NanoSVG - SVG parsing and rasterization
- PugiXML - XML parsing (used by OpenImageIO)
- JSON library - JSON parsing and serialization (`extern/json/`)
- Binreloc - Binary relocation library (Linux)

**Threading:**
- Intel TBB - Task-based parallelism (optional, `WITH_TBB`)

**VR/XR:**
- OpenXR - Extended Reality support specification

**Internationalization:**
- FreeType - Font rendering and i18n support
- International Components for Unicode (ICU) - Text processing

**Testing:**
- Google Test - Unit testing (`extern/gtest/`, `extern/gmock/`)

## Configuration

**Environment:**
- Configurable via CMake options (boolean flags for 150+ feature toggles)
- Platform-specific settings for Windows, macOS, Linux
- GPU compute device selection (CUDA, OptiX, HIP, Metal, oneAPI)
- Feature modules can be enabled/disabled at build time

**Build:**
- Primary config: `CMakeLists.txt` - 2000+ lines of configuration
- CMake modules: `build_files/cmake/Modules/` - FindPythonLibsUnix.cmake, etc.
- Platform-specific modules: `build_files/cmake/platform/`
- Build environment scripts: `build_files/build_environment/cmake/`

**Key Configuration Files:**
- `CMakeLists.txt` - Root build configuration
- `pyproject.toml` - Python tool configurations (autopep8, black formatters)
- `.clang-format` - Code formatting rules
- `.clang-tidy` - Static analysis configuration
- `.editorconfig` - Cross-editor configuration
- `build_files/cmake/macros.cmake` - CMake macro definitions
- `GNUmakefile` - Alternative make-based build interface

## Platform Requirements

**Development:**
- CMake 3.10 or newer
- Compiler: GCC 14+, Clang 17+, MSVC 2019+, or Apple Clang
- Python 3.13+ (for building and scripting)
- Git with LFS (Large File Storage) for binary assets
- Platform-specific libraries (X11/Wayland on Linux, Cocoa on macOS, Windows SDK on Windows)

**Optional Development:**
- CUDA Toolkit (for NVIDIA GPU compilation)
- OptiX SDK (for NVIDIA ray tracing)
- Intel GPGPU support libraries (for oneAPI compilation)

**Production:**
- Linux (X11, Wayland support), Windows, macOS (10.9+)
- Modern GPU preferred for rendering (NVIDIA, AMD, Intel, Apple Metal)
- 2GB+ RAM recommended (more for complex scenes)

**Rendering Targets:**
- CPU rendering via Cycles
- GPU rendering via CUDA, OptiX, HIP, Metal, oneAPI
- Headless rendering mode available for server/batch use

---

*Stack analysis: 2026-04-01*
