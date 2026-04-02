# ZLIB finder for Emscripten WASM builds backed by the sysroot static library.
if(DEFINED ENV{EMSDK})
  set(_ZLIB_SYSROOT_ROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot")
else()
  set(_ZLIB_SYSROOT_ROOT "/emsdk/upstream/emscripten/cache/sysroot")
endif()

set(_ZLIB_SYSROOT "${_ZLIB_SYSROOT_ROOT}/include")

set(ZLIB_FOUND TRUE)
set(ZLIB_INCLUDE_DIRS "${_ZLIB_SYSROOT}")
set(ZLIB_LIBRARIES "${_ZLIB_SYSROOT_ROOT}/lib/wasm32-emscripten/libz.a")
set(ZLIB_LIBRARY "${ZLIB_LIBRARIES}")
set(ZLIB_INCLUDE_DIR "${_ZLIB_SYSROOT}")
set(ZLIB_VERSION_STRING "1.2.13")
if(NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB INTERFACE IMPORTED)
  set_target_properties(ZLIB::ZLIB PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${ZLIB_LIBRARY}"
  )
endif()
