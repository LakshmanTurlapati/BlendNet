# Fake Freetype finder for Emscripten WASM builds
# Emscripten provides freetype via -sUSE_FREETYPE=1
if(DEFINED ENV{EMSDK})
  set(_FREETYPE_SYSROOT "$ENV{EMSDK}/upstream/emscripten/cache/sysroot/include")
else()
  set(_FREETYPE_SYSROOT "/emsdk/upstream/emscripten/cache/sysroot/include")
endif()

set(Freetype_FOUND TRUE)
set(FREETYPE_FOUND TRUE)
set(FREETYPE_INCLUDE_DIR "${_FREETYPE_SYSROOT}")
set(FREETYPE_INCLUDE_DIR_ft2build "${_FREETYPE_SYSROOT}")
set(FREETYPE_INCLUDE_DIR_freetype2 "${_FREETYPE_SYSROOT}/freetype2")
set(FREETYPE_INCLUDE_DIRS
    "${FREETYPE_INCLUDE_DIR}"
    "${FREETYPE_INCLUDE_DIR_freetype2}")
set(FREETYPE_LIBRARIES "")
set(FREETYPE_LIBRARY "freetype")
set(FREETYPE_VERSION_STRING "2.13.0")
# Skip brotli check
function(check_freetype_for_brotli)
endfunction()
if(NOT TARGET Freetype::Freetype)
  add_library(Freetype::Freetype INTERFACE IMPORTED)
  set_target_properties(Freetype::Freetype PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${FREETYPE_INCLUDE_DIRS}"
  )
endif()
