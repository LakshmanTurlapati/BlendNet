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
  -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0
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
  -sENVIRONMENT=web,worker
  -sEXPORTED_FUNCTIONS=_main,_wasm_init,_wasm_load_blend,_wasm_query_scene,_wasm_memory_usage
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,MEMFS
)

# =============================================================================
# Apply Flags
# =============================================================================

add_compile_options(${WASM_COMPILE_FLAGS})
add_link_options(${WASM_LINK_FLAGS})

# =============================================================================
# Build Type Configuration
# =============================================================================

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  # Debug: assertions, source maps, readable output
  add_compile_options(-g -gsource-map)
  add_link_options(
    -sASSERTIONS=2
    -g
    -gsource-map
  )
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
  # Release: maximum optimization, closure compiler for JS minification
  add_compile_options(-O3)
  add_link_options(
    -O3
    --closure 1
  )
endif()

message(STATUS "[emscripten_overrides] WASM compile flags: ${WASM_COMPILE_FLAGS}")
message(STATUS "[emscripten_overrides] WASM link flags: ${WASM_LINK_FLAGS}")
message(STATUS "[emscripten_overrides] Build type: ${CMAKE_BUILD_TYPE}")
