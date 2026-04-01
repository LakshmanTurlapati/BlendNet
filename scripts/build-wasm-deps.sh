#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Stage 2 of the three-stage Blender WASM build pipeline.
#
# Resolves and verifies Emscripten port dependencies required by the
# headless Blender WASM build. Most dependencies are either handled by
# Emscripten's built-in ports system or disabled via WITH_* flags.
#
# Emscripten Ports Used:
#   -sUSE_ZLIB=1      Compression (required by blenloader for .blend files)
#   -sUSE_LIBPNG=1    PNG image support
#   -sUSE_FREETYPE=1  Font rendering and internationalization
#   -sUSE_BULLET=1    Physics engine (rigid body dynamics)
#   -sUSE_SDL=0       SDL disabled -- using headless mode, no display
#
# Dependencies Disabled via WITH_* Flags:
#   TBB, OpenColorIO, OpenSubdiv, OpenVDB, OpenImageDenoise, Audaspace,
#   FFTW3, OpenXR, GMP, Freestyle, Potrace, Haru, OpenEXR, FFmpeg,
#   USD, Alembic -- all disabled in headless build configuration.
#
# Header-Only Dependencies (no compilation needed):
#   Eigen -- used by IK solvers and geometry processing
#
# Usage:
#   ./scripts/build-wasm-deps.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[wasm-deps] Stage 2: Verifying Emscripten port dependencies"

# Source emsdk environment if available
if [ -n "${EMSDK:-}" ]; then
    echo "[wasm-deps] Sourcing emsdk_env.sh from EMSDK=${EMSDK}"
    source "${EMSDK}/emsdk_env.sh" 2>/dev/null || true
fi

# Verify Emscripten is available
if ! command -v emcc &>/dev/null; then
    echo "[wasm-deps] ERROR: emcc not found. Ensure Emscripten SDK is installed and sourced." >&2
    exit 1
fi

EMCC_VERSION=$(emcc --version 2>&1 | head -1)
echo "[wasm-deps] Emscripten version: ${EMCC_VERSION}"

# Verify required ports are available by triggering port downloads.
# Emscripten ports are fetched on first use during compilation.
# This step pre-fetches them to avoid delays during the main build.
echo "[wasm-deps] Pre-fetching Emscripten ports..."

PORTS_TEST_DIR=$(mktemp -d)
cat > "${PORTS_TEST_DIR}/test.c" << 'TESTEOF'
#include <stdio.h>
int main() { printf("ports ok\n"); return 0; }
TESTEOF

# Test that the required ports can be resolved
emcc "${PORTS_TEST_DIR}/test.c" \
    -sUSE_ZLIB=1 \
    -sUSE_LIBPNG=1 \
    -sUSE_FREETYPE=1 \
    -sUSE_BULLET=1 \
    -o "${PORTS_TEST_DIR}/test.js" 2>&1 || {
    echo "[wasm-deps] ERROR: Failed to resolve Emscripten ports" >&2
    rm -rf "${PORTS_TEST_DIR}"
    exit 1
}

rm -rf "${PORTS_TEST_DIR}"

echo "[wasm-deps] All required Emscripten ports verified successfully."
echo "[wasm-deps] Stage 2 complete."
