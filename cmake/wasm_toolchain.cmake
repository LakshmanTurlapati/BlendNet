# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Additional toolchain overrides for Blender WASM cross-compilation.
#
# This file supplements the Emscripten toolchain file with Blender-specific
# configuration. It is included after the Emscripten toolchain is active.

# Set CMAKE_CROSSCOMPILING_EMULATOR so that CMake-based tests can run
# generated executables via Node.js during the build process.
set(CMAKE_CROSSCOMPILING_EMULATOR "node" CACHE STRING
  "Use Node.js to execute WASM binaries during cross-compilation")

# Platform detection variables for Blender's build system.
# These help Blender's CMakeLists.txt detect the WASM target.
set(WASM TRUE CACHE BOOL "Building for WebAssembly target")
set(EMSCRIPTEN TRUE CACHE BOOL "Building with Emscripten toolchain")

# Include the central WASM build configuration with all compile/link flags.
include("${CMAKE_CURRENT_LIST_DIR}/emscripten_overrides.cmake")

message(STATUS "[wasm_toolchain] Emscripten toolchain overrides loaded")
message(STATUS "[wasm_toolchain] Cross-compiling emulator: ${CMAKE_CROSSCOMPILING_EMULATOR}")
