# Zstd finder for Emscripten WASM builds backed by the sysroot static library.
if(DEFINED ENV{EMSDK})
  set(_ZSTD_SYSROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot")
else()
  set(_ZSTD_SYSROOT "/emsdk/upstream/emscripten/cache/sysroot")
endif()

set(Zstd_FOUND TRUE)
set(ZSTD_FOUND TRUE)
set(ZSTD_INCLUDE_DIR "${_ZSTD_SYSROOT}/include")
set(ZSTD_INCLUDE_DIRS "${ZSTD_INCLUDE_DIR}")
set(ZSTD_LIBRARY "${_ZSTD_SYSROOT}/lib/libzstd.a")
set(ZSTD_LIBRARIES "${ZSTD_LIBRARY}")
if(NOT TARGET zstd::zstd)
  add_library(zstd::zstd INTERFACE IMPORTED)
  set_target_properties(zstd::zstd PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ZSTD_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${ZSTD_LIBRARY}"
  )
endif()
