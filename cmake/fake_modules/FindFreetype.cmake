# Freetype finder for Emscripten WASM builds backed by the sysroot static library.
if(DEFINED ENV{EMSDK})
  set(_FREETYPE_SYSROOT_ROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot")
else()
  set(_FREETYPE_SYSROOT_ROOT "/emsdk/upstream/emscripten/cache/sysroot")
endif()

set(_FREETYPE_SYSROOT "${_FREETYPE_SYSROOT_ROOT}/include")
set(_FREETYPE_LIBROOT "${_FREETYPE_SYSROOT_ROOT}/lib/wasm32-emscripten")

set(Freetype_FOUND TRUE)
set(FREETYPE_FOUND TRUE)
set(FREETYPE_INCLUDE_DIR "${_FREETYPE_SYSROOT}")
set(FREETYPE_INCLUDE_DIR_ft2build "${_FREETYPE_SYSROOT}")
set(FREETYPE_INCLUDE_DIR_freetype2 "${_FREETYPE_SYSROOT}/freetype2")
set(FREETYPE_INCLUDE_DIRS
    "${FREETYPE_INCLUDE_DIR}"
    "${FREETYPE_INCLUDE_DIR_freetype2}")
set(FREETYPE_LIBRARY "${_FREETYPE_LIBROOT}/libfreetype.a")
set(FREETYPE_LIBRARIES "${FREETYPE_LIBRARY}")
set(FREETYPE_VERSION_STRING "2.13.0")
# Skip brotli check
function(check_freetype_for_brotli)
endfunction()
if(NOT TARGET Freetype::Freetype)
  add_library(Freetype::Freetype INTERFACE IMPORTED)
  set_target_properties(Freetype::Freetype PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FREETYPE_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "${FREETYPE_LIBRARY}"
  )
endif()
