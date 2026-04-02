# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Central WASM build configuration for Blender Emscripten cross-compilation.
#
# This file defines all compile and link flags specific to the WASM target.
# It is included by the WASM build script (scripts/build-wasm.sh) during
# CMake configuration via -C flag (initial cache).
#
# Requirements addressed:
#   BUILD-01: Core WASM compilation via Emscripten
#   BUILD-03: Threading via pthreads mapped to Web Workers
#   BUILD-04: Memory management within WASM32 4GB address space
#   BUILD-06: Non-blocking main loop via PROXY_TO_PTHREAD
#   BUILD-08: WASM SIMD enabled for math-heavy operations

# =============================================================================
# WASM Compile Flags
# =============================================================================

set(WASM_COMPILE_FLAGS
  -pthread
  -msimd128
  -mrelaxed-simd
  -fwasm-exceptions
  -include
  stdlib.h
  -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0
  -DFE_DIVBYZERO=0
  -DFE_INVALID=0
)

# =============================================================================
# WASM Link Flags
# =============================================================================

set(WASM_LINK_FLAGS
  # Threading (BUILD-03)
  -pthread
  -sPROXY_TO_PTHREAD
  -sALLOW_BLOCKING_ON_MAIN_THREAD=0
  -sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency
  -sPTHREAD_POOL_SIZE_STRICT=0

  # Memory management (BUILD-04)
  -sALLOW_MEMORY_GROWTH=1
  -sINITIAL_MEMORY=256MB
  -sMAXIMUM_MEMORY=4GB
  -sMALLOC=mimalloc
  -sSTACK_SIZE=2MB

  # Exception handling
  -fwasm-exceptions

  # Environment and runtime
  # Include 'node' so host tools (makesdna, makesrna, datatoc, shader_tool) can
  # run via Node.js during the build. NODERAWFS allows filesystem access from node.
  # Browsers ignore the node environment code.
  -sENVIRONMENT=web,worker,node
  -sNODERAWFS=1
  -sEXPORTED_FUNCTIONS=_main,_wasm_init,_wasm_load_blend,_wasm_query_scene,_wasm_memory_usage
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,MEMFS
)

# =============================================================================
# Propagate Flags Through The Initial Cache
# =============================================================================

string(REPLACE ";" " " WASM_COMPILE_FLAGS_STR "${WASM_COMPILE_FLAGS}")
string(REPLACE ";" " " WASM_LINK_FLAGS_STR "${WASM_LINK_FLAGS}")

set(CMAKE_C_FLAGS "${WASM_COMPILE_FLAGS_STR}" CACHE STRING "Blender Web WASM C flags" FORCE)
set(CMAKE_CXX_FLAGS "${WASM_COMPILE_FLAGS_STR}" CACHE STRING "Blender Web WASM C++ flags" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "${WASM_LINK_FLAGS_STR}" CACHE STRING "Blender Web WASM executable link flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "${WASM_LINK_FLAGS_STR}" CACHE STRING "Blender Web WASM shared link flags" FORCE)
set(CMAKE_MODULE_LINKER_FLAGS "${WASM_LINK_FLAGS_STR}" CACHE STRING "Blender Web WASM module link flags" FORCE)

add_compile_options(${WASM_COMPILE_FLAGS})
add_link_options(${WASM_LINK_FLAGS})

# =============================================================================
# Build Type Configuration
# =============================================================================

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  # Debug: assertions, source maps, readable output
  set(CMAKE_C_FLAGS_DEBUG "-g -gsource-map" CACHE STRING "Blender Web WASM debug C flags" FORCE)
  set(CMAKE_CXX_FLAGS_DEBUG "-g -gsource-map" CACHE STRING "Blender Web WASM debug C++ flags" FORCE)
  set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-sASSERTIONS=2 -g -gsource-map" CACHE STRING "Blender Web WASM debug executable link flags" FORCE)
  set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "-sASSERTIONS=2 -g -gsource-map" CACHE STRING "Blender Web WASM debug shared link flags" FORCE)
  set(CMAKE_MODULE_LINKER_FLAGS_DEBUG "-sASSERTIONS=2 -g -gsource-map" CACHE STRING "Blender Web WASM debug module link flags" FORCE)
  add_compile_options(-g -gsource-map)
  add_link_options(
    -sASSERTIONS=2
    -g
    -gsource-map
  )
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
  # Release: maximum optimization, closure compiler for JS minification
  set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG" CACHE STRING "Blender Web WASM release C flags" FORCE)
  set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG" CACHE STRING "Blender Web WASM release C++ flags" FORCE)
  set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-O3 --closure 1" CACHE STRING "Blender Web WASM release executable link flags" FORCE)
  set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "-O3 --closure 1" CACHE STRING "Blender Web WASM release shared link flags" FORCE)
  set(CMAKE_MODULE_LINKER_FLAGS_RELEASE "-O3 --closure 1" CACHE STRING "Blender Web WASM release module link flags" FORCE)
  add_compile_options(-O3)
  add_link_options(
    -O3
    --closure 1
  )
endif()

message(STATUS "[emscripten_overrides] WASM compile flags: ${WASM_COMPILE_FLAGS}")
message(STATUS "[emscripten_overrides] WASM link flags: ${WASM_LINK_FLAGS}")
message(STATUS "[emscripten_overrides] Build type: ${CMAKE_BUILD_TYPE}")
