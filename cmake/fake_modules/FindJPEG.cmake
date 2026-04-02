# JPEG finder for Emscripten WASM builds backed by the sysroot static library.
if(DEFINED ENV{EMSDK})
  set(_JPEG_SYSROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot")
else()
  set(_JPEG_SYSROOT "/emsdk/upstream/emscripten/cache/sysroot")
endif()

set(JPEG_FOUND TRUE)
set(JPEG_INCLUDE_DIR "${_JPEG_SYSROOT}/include")
set(JPEG_INCLUDE_DIRS "${JPEG_INCLUDE_DIR}")
set(JPEG_LIBRARY "${_JPEG_SYSROOT}/lib/wasm32-emscripten/libjpeg.a")
set(JPEG_LIBRARIES "${JPEG_LIBRARY}")
if(NOT TARGET JPEG::JPEG)
  add_library(JPEG::JPEG INTERFACE IMPORTED)
  set_target_properties(JPEG::JPEG PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${JPEG_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${JPEG_LIBRARY}"
  )
endif()
