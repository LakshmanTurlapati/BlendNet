#!/bin/bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Install all Blender WASM dependencies into Emscripten sysroot.
# Run inside Docker container: docker compose run --rm blender-wasm-build bash scripts/setup-wasm-deps.sh

set -e
SYSROOT=/emsdk/upstream/emscripten/cache/sysroot
JOBS=$(nproc)

echo "=== Installing system packages ==="
apt-get update -qq
apt-get install -y -qq gcc-14 g++-14 git 2>&1 | tail -3

echo "=== Step 1: Emscripten ports (JPEG, PNG, ZLIB) ==="
embuilder build libjpeg libpng zlib 2>&1 | tail -5

echo "=== Step 2: Brotli ==="
cd /tmp && rm -rf brotli
git clone --depth 1 https://github.com/google/brotli.git 2>&1 | tail -1
cd brotli && mkdir build-em && cd build-em
emcmake cmake .. -DCMAKE_INSTALL_PREFIX=$SYSROOT -DCMAKE_BUILD_TYPE=Release -DBROTLI_DISABLE_TESTS=ON 2>&1 | tail -3
cmake --build . -j$JOBS 2>&1 | tail -3
cmake --install . 2>&1 | tail -3
echo "Brotli: OK"

echo "=== Step 3: Zstd ==="
cd /tmp && rm -rf zstd
git clone --depth 1 --branch v1.5.6 https://github.com/facebook/zstd.git 2>&1 | tail -1
cd zstd/build/cmake && mkdir -p build && cd build
emcmake cmake .. -DCMAKE_INSTALL_PREFIX=$SYSROOT -DCMAKE_BUILD_TYPE=Release \
  -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_STATIC=ON 2>&1 | tail -3
cmake --build . -j$JOBS 2>&1 | tail -3
cmake --install . 2>&1 | tail -3
echo "Zstd: OK"

echo "=== Step 4: Freetype (with Brotli + zlib + png) ==="
cd /tmp && rm -rf freetype
git clone --depth 1 --branch VER-2-13-3 https://github.com/freetype/freetype.git 2>&1 | tail -1
cd freetype && mkdir build-em && cd build-em
emcmake cmake .. \
  -DCMAKE_INSTALL_PREFIX=$SYSROOT \
  -DCMAKE_BUILD_TYPE=Release \
  -DFT_REQUIRE_BROTLI=ON \
  -DFT_REQUIRE_ZLIB=ON \
  -DFT_REQUIRE_PNG=ON \
  -DFT_DISABLE_HARFBUZZ=ON \
  -DBROTLIDEC_INCLUDE_DIRS=$SYSROOT/include \
  -DBROTLIDEC_LIBRARIES="$SYSROOT/lib/libbrotlidec.a;$SYSROOT/lib/libbrotlicommon.a" \
  -DZLIB_INCLUDE_DIR=$SYSROOT/include \
  -DZLIB_LIBRARY=$SYSROOT/lib/wasm32-emscripten/libz.a \
  -DPNG_INCLUDE_DIRS=$SYSROOT/include \
  -DPNG_LIBRARIES=$SYSROOT/lib/wasm32-emscripten/libpng.a \
  -DPNG_PNG_INCLUDE_DIR=$SYSROOT/include \
  -DPNG_LIBRARY=$SYSROOT/lib/wasm32-emscripten/libpng.a \
  2>&1 | tail -5
cmake --build . -j$JOBS 2>&1 | tail -5
cmake --install . 2>&1 | tail -5
echo "Freetype: OK"

echo "=== Step 5: fmt (header-only) ==="
cd /tmp && rm -rf fmt
git clone --depth 1 --branch 11.1.4 https://github.com/fmtlib/fmt.git 2>&1 | tail -1
cp -r /tmp/fmt/include/fmt $SYSROOT/include/
mkdir -p $SYSROOT/lib/cmake/fmt
cat > $SYSROOT/lib/cmake/fmt/fmt-config.cmake << 'EOF'
if(NOT TARGET fmt::fmt)
  add_library(fmt::fmt INTERFACE IMPORTED)
  set_target_properties(fmt::fmt PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../../include"
    INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1"
  )
  add_library(fmt::fmt-header-only INTERFACE IMPORTED)
  set_target_properties(fmt::fmt-header-only PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../../include"
    INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1"
  )
endif()
EOF
cat > $SYSROOT/lib/cmake/fmt/fmt-config-version.cmake << 'EOF'
set(PACKAGE_VERSION "11.1.4")
set(PACKAGE_VERSION_EXACT FALSE)
set(PACKAGE_VERSION_COMPATIBLE TRUE)
set(PACKAGE_VERSION_UNSUITABLE FALSE)
EOF
echo "fmt: OK"

echo "=== Step 6: Epoxy stub ==="
mkdir -p $SYSROOT/include/epoxy
cat > $SYSROOT/include/epoxy/gl.h << 'EOF'
#ifndef EPOXY_GL_H
#define EPOXY_GL_H
#include <GLES3/gl3.h>
#endif
EOF
echo "void epoxy_stub(void) {}" > /tmp/epoxy_stub.c
emcc -c /tmp/epoxy_stub.c -o /tmp/epoxy_stub.o
emar rcs $SYSROOT/lib/wasm32-emscripten/libepoxy.a /tmp/epoxy_stub.o
echo "Epoxy stub: OK"

echo ""
echo "=== All dependencies installed ==="
echo "Libraries in sysroot:"
ls $SYSROOT/lib/libzstd.a $SYSROOT/lib/libbrotli*.a $SYSROOT/lib/libfreetype.a \
   $SYSROOT/lib/wasm32-emscripten/libjpeg.a $SYSROOT/lib/wasm32-emscripten/libpng.a \
   $SYSROOT/lib/wasm32-emscripten/libz.a $SYSROOT/lib/wasm32-emscripten/libepoxy.a \
   2>/dev/null
echo "CMake configs:"
ls $SYSROOT/lib/cmake/fmt/fmt-config.cmake 2>/dev/null
echo "DONE"
