# Fake sse2neon finder for Emscripten WASM builds
# WASM uses WASM SIMD, not SSE2/NEON translation
set(sse2neon_FOUND TRUE)
set(SSE2NEON_FOUND TRUE)
set(SSE2NEON_INCLUDE_DIR "/tmp/fake_sse2neon")
set(SSE2NEON_INCLUDE_DIRS "/tmp/fake_sse2neon")
