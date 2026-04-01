#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Stage 3 of the three-stage Blender WASM build pipeline.
#
# Orchestrates the cross-compilation of Blender to WebAssembly using
# Emscripten. Requires Stage 1 (host tools) to be complete.
#
# This script is structured with clearly marked sections to support
# cross-plan modifications. Plan 03 will extend the CMake Configuration
# and Post-Build sections.
#
# Usage:
#   ./scripts/build-wasm.sh
#
# Prerequisites:
#   - Emscripten SDK installed and available (EMSDK set or emcmake on PATH)
#   - Stage 1 host tools built (scripts/build-host-tools.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build-wasm"
BLENDER_SRC="${PROJECT_ROOT}/Blender Mirror"
CMAKE_DIR="${PROJECT_ROOT}/cmake"

echo "[build-wasm] Stage 3: Cross-compiling Blender to WebAssembly"
echo "[build-wasm] Blender source: ${BLENDER_SRC}"
echo "[build-wasm] Build directory: ${BUILD_DIR}"

BUILD_START_TIME=$(date +%s)

# === SECTION: Environment Setup ===
# Source emsdk_env.sh to make emcmake and emmake available.

if [ -n "${EMSDK:-}" ]; then
    echo "[build-wasm] Sourcing emsdk_env.sh from EMSDK=${EMSDK}"
    source "${EMSDK}/emsdk_env.sh" 2>/dev/null || true
fi

# Verify Emscripten tools are available
if ! command -v emcmake &>/dev/null; then
    echo "[build-wasm] ERROR: emcmake not found. Ensure Emscripten SDK is installed and sourced." >&2
    exit 1
fi

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# === SECTION: CMake Configuration ===
# Configure Blender for WASM cross-compilation with all required flags.
# The emscripten_overrides.cmake file is loaded via -C to set WASM-specific
# compile and link flags (SIMD, threading, memory, PROXY_TO_PTHREAD).
# The wasm_sources.cmake file defines the custom entry point and include paths.

echo "[build-wasm] Configuring CMake with Emscripten..."

# Load wasm_sources.cmake to define WASM_ENTRY_POINT_SRC and WASM_BLENDER_INCLUDE_DIRS
WASM_SOURCES_CMAKE="${CMAKE_DIR}/wasm_sources.cmake"
if [ ! -f "${WASM_SOURCES_CMAKE}" ]; then
    echo "[build-wasm] ERROR: cmake/wasm_sources.cmake not found at ${WASM_SOURCES_CMAKE}" >&2
    exit 1
fi
echo "[build-wasm] Including wasm_sources.cmake: ${WASM_SOURCES_CMAKE}"

# Custom entry point replaces Blender's standard creator.cc
WASM_ENTRY_SRC="${PROJECT_ROOT}/source/wasm_headless_main.cc"
if [ ! -f "${WASM_ENTRY_SRC}" ]; then
    echo "[build-wasm] ERROR: Custom entry point not found at ${WASM_ENTRY_SRC}" >&2
    exit 1
fi
echo "[build-wasm] Custom entry point: ${WASM_ENTRY_SRC}"

emcmake cmake "${BLENDER_SRC}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -C "${CMAKE_DIR}/emscripten_overrides.cmake" \
    -C "${WASM_SOURCES_CMAKE}" \
    \
    -DWITH_HEADLESS=ON \
    \
    -DWITH_BULLET=ON \
    -DWITH_IK_SOLVER=ON \
    -DWITH_IK_ITASC=ON \
    -DWITH_MOD_REMESH=ON \
    \
    -DWITH_PYTHON=OFF \
    -DWITH_CYCLES=OFF \
    -DWITH_GHOST_SDL=OFF \
    -DWITH_GHOST_X11=OFF \
    -DWITH_GHOST_WAYLAND=OFF \
    -DWITH_OPENGL_BACKEND=OFF \
    -DWITH_VULKAN_BACKEND=OFF \
    -DWITH_TBB=OFF \
    -DWITH_OPENCOLORIO=OFF \
    -DWITH_OPENSUBDIV=OFF \
    -DWITH_OPENVDB=OFF \
    -DWITH_OPENIMAGEDENOISE=OFF \
    -DWITH_AUDASPACE=OFF \
    -DWITH_FFTW3=OFF \
    -DWITH_XR_OPENXR=OFF \
    -DWITH_GMP=OFF \
    -DWITH_FREESTYLE=OFF \
    -DWITH_POTRACE=OFF \
    -DWITH_HARU=OFF \
    -DWITH_IMAGE_OPENEXR=OFF \
    -DWITH_CODEC_FFMPEG=OFF \
    -DWITH_USD=OFF \
    -DWITH_ALEMBIC=OFF \
    -DWITH_MOD_FLUID=OFF \
    -DWITH_INTERNATIONAL=OFF \
    -DWITH_CYCLES_DEVICE_CUDA=OFF \
    -DWITH_CYCLES_DEVICE_OPTIX=OFF \
    -DWITH_CYCLES_DEVICE_HIP=OFF \
    -DWITH_CYCLES_DEVICE_ONEAPI=OFF \
    -DWITH_CYCLES_DEVICE_METAL=OFF

echo "[build-wasm] CMake configuration complete."

# === SECTION: Compilation ===
# Build Blender with Emscripten using all available cores.

echo "[build-wasm] Starting WASM compilation..."

emmake ninja -j$(nproc)

echo "[build-wasm] WASM compilation complete."

# === SECTION: Post-Build ===
# Brotli compression, size reporting, and build metrics.

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

echo "[build-wasm] Compilation complete. Running post-build steps..."
echo "[build-wasm] Total compilation time: ${BUILD_DURATION} seconds"

# Report output file sizes if present
if ls "${BUILD_DIR}"/*.wasm 1>/dev/null 2>&1; then
    echo "[build-wasm] WASM output files:"
    ls -lh "${BUILD_DIR}"/*.wasm
fi

# Brotli compression for serving (BUILD-07)
if [ -f "${BUILD_DIR}/blender.wasm" ]; then
    # Report uncompressed size
    WASM_SIZE=$(stat -f%z "${BUILD_DIR}/blender.wasm" 2>/dev/null || stat -c%s "${BUILD_DIR}/blender.wasm" 2>/dev/null)
    echo "[build] Uncompressed WASM size: ${WASM_SIZE} bytes ($(echo "scale=2; ${WASM_SIZE}/1048576" | bc) MB)"

    # Compress with Brotli (best compression)
    echo "[build] Compressing with Brotli (--best)..."
    if command -v brotli &>/dev/null; then
        brotli --best --force "${BUILD_DIR}/blender.wasm" -o "${BUILD_DIR}/blender.wasm.br"

        BR_SIZE=$(stat -f%z "${BUILD_DIR}/blender.wasm.br" 2>/dev/null || stat -c%s "${BUILD_DIR}/blender.wasm.br" 2>/dev/null)
        echo "[build] Brotli compressed size: ${BR_SIZE} bytes ($(echo "scale=2; ${BR_SIZE}/1048576" | bc) MB)"
        RATIO=$(echo "scale=1; ${BR_SIZE}*100/${WASM_SIZE}" | bc)
        echo "[build] Compression ratio: ${RATIO}%"

        # BUILD-07 target: compressed size under 30MB
        BR_MB=$(echo "scale=0; ${BR_SIZE}/1048576" | bc)
        if [ "${BR_MB}" -gt 30 ]; then
            echo "[build] WARNING: Compressed size exceeds 30MB target (${BR_MB} MB)"
        else
            echo "[build] PASS: Compressed size within 30MB target (${BR_MB} MB)"
        fi
    else
        echo "[build] WARNING: brotli command not found -- skipping compression"
        echo "[build] Install with: apt-get install brotli (Linux) or brew install brotli (macOS)"
    fi
else
    echo "[build] WARNING: blender.wasm not found -- skipping compression"
    echo "[build] This is expected if the build encountered errors."
fi

echo "[build-wasm] Stage 3 complete."
