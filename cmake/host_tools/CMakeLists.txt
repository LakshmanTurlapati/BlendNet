# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Minimal standalone build for Blender host tools (makesdna, datatoc).
# These must run on the build host during cross-compilation to WASM.
# This CMakeLists.txt bypasses Blender's full build system to avoid
# the macOS precompiled library dependency.

cmake_minimum_required(VERSION 3.10)
project(BlenderHostTools LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Path to the Blender source tree
if(NOT DEFINED BLENDER_SRC)
  get_filename_component(BLENDER_SRC "${CMAKE_CURRENT_LIST_DIR}/../../Blender Mirror" ABSOLUTE)
endif()

message(STATUS "Blender source: ${BLENDER_SRC}")

# Stub include directory for OpenImageIO
get_filename_component(STUBS_DIR "${CMAKE_CURRENT_LIST_DIR}/../stubs" ABSOLUTE)

# Find fmt headers (needed by BLI_string_ref.hh)
find_path(FMT_INCLUDE_DIR fmt/format.h
  PATHS /opt/homebrew/opt/fmt/include /usr/local/include /usr/include
)
if(NOT FMT_INCLUDE_DIR)
  message(FATAL_ERROR "fmt library headers not found. Install with: brew install fmt")
endif()
message(STATUS "fmt include: ${FMT_INCLUDE_DIR}")

# Common include directories
set(COMMON_INCLUDES
  ${BLENDER_SRC}/source/blender/makesdna
  ${BLENDER_SRC}/source/blender/blenlib
  ${BLENDER_SRC}/source/blender/imbuf
  ${BLENDER_SRC}/source/blender/imbuf/movie
  ${BLENDER_SRC}/intern/atomic/.
  ${BLENDER_SRC}/intern/guardedalloc
  ${STUBS_DIR}
  ${FMT_INCLUDE_DIR}
)

# Definitions
add_definitions(
  -DWITH_DNA_GHASH
  -DWITH_ASSERT_ABORT
  -D__LITTLE_ENDIAN__
)

# ---- Generate dna_includes_all.h and dna_includes_as_strings.h ----
# Collect all DNA header files from the Blender source
file(GLOB DNA_HEADERS "${BLENDER_SRC}/source/blender/makesdna/DNA_*.h")
list(SORT DNA_HEADERS)

set(DNA_INCLUDE_TEXT "/* Do not edit manually, changes will be overwritten. */\n")
set(DNA_FILE_LIST "/* Do not edit manually, changes will be overwritten. */\n")
foreach(header ${DNA_HEADERS})
  string(APPEND DNA_INCLUDE_TEXT "#include \"${header}\"\n")
  get_filename_component(dna_header_file ${header} NAME)
  string(APPEND DNA_FILE_LIST "\t\"${dna_header_file}\",\n")
endforeach()

set(dna_header_include_file "${CMAKE_CURRENT_BINARY_DIR}/dna_includes_all.h")
set(dna_header_string_file "${CMAKE_CURRENT_BINARY_DIR}/dna_includes_as_strings.h")

file(GENERATE OUTPUT ${dna_header_include_file} CONTENT "${DNA_INCLUDE_TEXT}")
file(GENERATE OUTPUT ${dna_header_string_file} CONTENT "${DNA_FILE_LIST}")

# ---- guardedalloc library ----
add_library(bf_intern_guardedalloc STATIC
  ${BLENDER_SRC}/intern/guardedalloc/intern/mallocn.cc
  ${BLENDER_SRC}/intern/guardedalloc/intern/mallocn_guarded_impl.cc
  ${BLENDER_SRC}/intern/guardedalloc/intern/mallocn_lockfree_impl.cc
  ${BLENDER_SRC}/intern/guardedalloc/intern/leak_detector.cc
  ${BLENDER_SRC}/intern/guardedalloc/intern/memory_usage.cc
)
target_include_directories(bf_intern_guardedalloc PUBLIC
  ${BLENDER_SRC}/intern/guardedalloc
  ${BLENDER_SRC}/intern/atomic/.
  ${BLENDER_SRC}/source/blender/blenlib
  ${STUBS_DIR}
  ${FMT_INCLUDE_DIR}
)
target_compile_definitions(bf_intern_guardedalloc PRIVATE -D__LITTLE_ENDIAN__)

# ---- makesdna ----
add_executable(makesdna
  ${BLENDER_SRC}/source/blender/makesdna/intern/makesdna.cc
  ${BLENDER_SRC}/source/blender/makesdna/intern/dna_utils.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_assert.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_ghash.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_ghash_utils.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_linklist.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_memarena.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/BLI_mempool.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/listbase.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/string.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/hash_mm2a.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/gsqueue.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/threads.cc
  ${BLENDER_SRC}/source/blender/blenlib/intern/time.cc
  ${dna_header_include_file}
  ${dna_header_string_file}
)
target_include_directories(makesdna PRIVATE
  ${COMMON_INCLUDES}
  ${CMAKE_CURRENT_BINARY_DIR}
)
target_link_libraries(makesdna bf_intern_guardedalloc pthread)

# ---- datatoc ----
add_executable(datatoc
  ${BLENDER_SRC}/source/blender/datatoc/datatoc.cc
)
target_include_directories(datatoc PRIVATE ${COMMON_INCLUDES})

# Report what was built
message(STATUS "Host tools will be built: makesdna, datatoc")
