# Fake fmt finder for Emscripten WASM builds
# fmt is header-only; uses Emscripten sysroot include path
# The actual headers are installed by scripts/setup-wasm-deps.sh

# Detect sysroot: use EMSDK env var if available, else fallback
if(DEFINED ENV{EMSDK})
  set(_FMT_SYSROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot/include")
else()
  set(_FMT_SYSROOT "/emsdk/upstream/emscripten/cache/sysroot/include")
endif()

set(fmt_FOUND TRUE)
set(fmt_VERSION "11.1.4")
set(fmt_INCLUDE_DIRS "${_FMT_SYSROOT}")

if(NOT TARGET fmt::fmt)
  add_library(fmt::fmt INTERFACE IMPORTED)
  set_target_properties(fmt::fmt PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_FMT_SYSROOT}"
    INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1"
  )
endif()
if(NOT TARGET fmt::fmt-header-only)
  add_library(fmt::fmt-header-only INTERFACE IMPORTED)
  set_target_properties(fmt::fmt-header-only PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_FMT_SYSROOT}"
    INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1"
  )
endif()
