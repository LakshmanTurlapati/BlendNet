# PNG finder for Emscripten WASM builds backed by the sysroot static library.
if(DEFINED ENV{EMSDK})
  set(_PNG_SYSROOT_ROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot")
else()
  set(_PNG_SYSROOT_ROOT "/emsdk/upstream/emscripten/cache/sysroot")
endif()

set(_PNG_SYSROOT "${_PNG_SYSROOT_ROOT}/include")

set(PNG_FOUND TRUE)
set(PNG_INCLUDE_DIRS "${_PNG_SYSROOT}")
set(PNG_LIBRARIES "${_PNG_SYSROOT_ROOT}/lib/wasm32-emscripten/libpng.a")
set(PNG_LIBRARY "${PNG_LIBRARIES}")
set(PNG_PNG_INCLUDE_DIR "${_PNG_SYSROOT}")
set(PNG_VERSION_STRING "1.6.37")
if(NOT TARGET PNG::PNG)
  add_library(PNG::PNG INTERFACE IMPORTED)
  set_target_properties(PNG::PNG PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${PNG_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "${PNG_LIBRARY}"
  )
endif()
