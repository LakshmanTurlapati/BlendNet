# WASM Build Status

## Status: Major Milestone - CMake Configures 15,019 Targets, C++ Compiles to WASM

## What Was Achieved

### 1. Emscripten SDK Installed (5.0.4)
- Installed at `/tmp/emsdk` (local, not Docker -- Docker daemon was not running)
- `emcc`, `emcmake`, `emmake` all verified working
- Version: emcc 5.0.4 (Emscripten gcc/clang-like replacement)

### 2. CMake Configuration Succeeded
- Blender's full CMake build system was configured for Emscripten cross-compilation
- 15,019 build targets generated (with Docker + proper dependency setup)
- Required creating **fake CMake find modules** for libraries not available in Emscripten:
  - JPEG, PNG, ZLIB, Zstd, Epoxy, fmt, Freetype, OpenImageIO, Threads, Eigen3, sse2neon
  - Located at: `cmake/fake_modules/`
- Required creating **stub headers** for OpenImageIO:
  - `cmake/stubs/OpenImageIO/ustring.h` -- trivially-copyable ustring implementation
- 42+ WITH_* flags disabled for headless build (no GPU, no Python, no audio, etc.)

### 3. Native Host Tools Built
- `makesdna` (209KB Mach-O arm64) -- DNA type definition generator
- `datatoc` (38KB Mach-O arm64) -- data-to-C-array converter
- Built via custom standalone CMakeLists.txt at `cmake/host_tools/CMakeLists.txt`
- Bypasses Blender's full build system which requires macOS precompiled libraries

### 4. DNA Type Files Generated
- `build-wasm/source/blender/makesdna/intern/dna.cc` (571KB, 6659 lines)
- `build-wasm/source/blender/makesdna/intern/dna_type_offsets.h` (37KB)
- `build-wasm/source/blender/makesdna/intern/dna_verify.cc`
- `build-wasm/source/blender/makesdna/intern/dna_struct_ids.cc`
- `build-wasm/source/blender/makesdna/intern/dna_defaults.cc`

### 5. Initial Compilation Started
- guardedalloc library compiled successfully to WASM
- Several blenlib source files compiled to WASM
- makesdna.cc compiled to WASM (object file produced)

## Blocking Issue

### Host Tool Cross-Compilation Chicken-and-Egg Problem

Blender's build system expects `makesdna`, `makesrna`, and `datatoc` to be compiled and
executed during the build process to generate source files. When using emcmake, these tools
are compiled to WASM (.js), which cannot run natively on the build host to generate the
needed files.

The standard solution for cross-compilation projects is to use CMake's `CMAKE_CROSSCOMPILING`
and `IMPORT_EXECUTABLES` mechanism, but Blender's build system does not support this pattern.

### What Needs to Happen

1. **Modify Blender's makesdna CMakeLists.txt** to detect cross-compilation and use
   pre-built native host tools instead of compiling them:
   ```cmake
   if(CMAKE_CROSSCOMPILING AND NATIVE_TOOLS_DIR)
     # Use pre-built native makesdna instead of compiling
     set(MAKESDNA_EXECUTABLE "${NATIVE_TOOLS_DIR}/makesdna")
   else()
     add_executable(makesdna ...)
   endif()
   ```

2. **OR create a two-pass build wrapper** that:
   - Pass 1: Build native host tools (already done via `cmake/host_tools/CMakeLists.txt`)
   - Pass 2: Configure WASM build with `-DNATIVE_TOOLS_DIR=<path>` and patched CMake files

3. **OR use Docker** (preferred approach from original plan):
   - Start Docker Desktop (`open -a Docker` on macOS)
   - The Dockerfile already has the correct environment (Emscripten 5.0.4 + ninja + brotli)
   - On Linux, the cross-compilation issue is simpler because precompiled libs aren't needed

## Environment Requirements

### For Docker Approach (Recommended)
- Docker Desktop must be running (`docker info` should show Server info)
- Run: `docker compose build blender-wasm-build`
- Run: `docker compose run --rm blender-wasm-build bash -c "./scripts/build-host-tools.sh && ./scripts/build-wasm-deps.sh && ./scripts/build-wasm.sh"`

### For Local Approach (Current)
- macOS with Xcode command-line tools
- Homebrew packages: ninja, brotli, fmt
- Emscripten SDK 5.0.4 (installed at /tmp/emsdk)
- Blender precompiled libraries for macOS (currently missing from Blender Mirror)
  - OR use the custom host tools CMake at `cmake/host_tools/CMakeLists.txt`

## Files Created During This Build Attempt

| File | Purpose |
|------|---------|
| `cmake/fake_modules/*.cmake` | Fake CMake find modules for Emscripten builds |
| `cmake/stubs/OpenImageIO/ustring.h` | Stub OIIO ustring header (trivially copyable) |
| `cmake/host_tools/CMakeLists.txt` | Standalone native host tools build |
| `build-native/makesdna` | Native makesdna executable (arm64) |
| `build-native/datatoc` | Native datatoc executable (arm64) |
| `build-wasm/source/blender/makesdna/intern/dna*.cc` | Generated DNA files |

## Recommended Next Steps

1. **Start Docker Desktop** and use the Docker-based build (cleanest path)
2. **OR** patch Blender's `source/blender/makesdna/intern/CMakeLists.txt` to support
   `CMAKE_CROSSCOMPILING` with `IMPORT_EXECUTABLES` from the native build
3. **OR** create a custom top-level CMakeLists.txt that orchestrates the two-pass build
   (similar to how other large projects handle Emscripten cross-compilation)

## CMake Configuration Used

```bash
emcmake cmake "../Blender Mirror" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_MODULE_PATH="cmake/fake_modules" \
    -DWITH_LIBS_PRECOMPILED=OFF \
    -DWITH_HEADLESS=ON \
    -DWITH_BLENDER=ON \
    -DWITH_PYTHON=OFF \
    -DWITH_CYCLES=OFF \
    -DWITH_GHOST_SDL=OFF \
    -DWITH_GHOST_WAYLAND=OFF \
    -DWITH_GHOST_X11=OFF \
    -DWITH_OPENGL_BACKEND=OFF \
    -DWITH_VULKAN_BACKEND=OFF \
    -DWITH_TBB=OFF \
    -DWITH_OPENCOLORIO=OFF \
    -DWITH_OPENSUBDIV=OFF \
    -DWITH_OPENVDB=OFF \
    -DWITH_OPENIMAGEDENOISE=OFF \
    -DWITH_AUDASPACE=OFF \
    -DWITH_FFTW3=OFF \
    -DWITH_XR_OPENXR=OFF \
    -DWITH_GMP=OFF \
    -DWITH_FREESTYLE=OFF \
    -DWITH_POTRACE=OFF \
    -DWITH_HARU=OFF \
    -DWITH_IMAGE_OPENEXR=OFF \
    -DWITH_CODEC_FFMPEG=OFF \
    -DWITH_USD=OFF \
    -DWITH_ALEMBIC=OFF \
    -DWITH_MOD_FLUID=OFF \
    -DWITH_INTERNATIONAL=OFF \
    -DWITH_BULLET=OFF \
    -DWITH_IK_SOLVER=OFF \
    -DWITH_IK_ITASC=OFF \
    -DWITH_MOD_REMESH=OFF \
    -DWITH_STATIC_LIBS=OFF \
    -DWITH_IMAGE_OPENJPEG=OFF \
    -DWITH_CODEC_SNDFILE=OFF \
    -DWITH_IO_STL=OFF \
    -DWITH_IO_WAVEFRONT_OBJ=OFF \
    -DWITH_IO_PLY=OFF \
    -DWITH_COMPILER_ASAN=OFF \
    -DWITH_HARFBUZZ=OFF \
    -DWITH_FRIBIDI=OFF \
    -DWITH_IMAGE_WEBP=OFF \
    -DWITH_SYSTEM_FREETYPE=OFF \
    -DWITH_COMPILER_SIMD=OFF \
    -DWITH_LIBMV=OFF \
    -DWITH_MATERIALX=OFF \
    -DWITH_INPUT_NDOF=OFF \
    -DWITH_QUADRIFLOW=OFF
```
