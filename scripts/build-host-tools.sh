#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Stage 1 of the three-stage Blender WASM build pipeline.
#
# Builds native host tools (makesdna, makesrna, datatoc) that are required
# during Blender's cross-compilation to WASM. These tools are code generators
# that must run on the host machine, not in the WASM target environment.
#
# Usage:
#   ./scripts/build-host-tools.sh
#
# Output:
#   build-native/bin/makesdna
#   build-native/bin/makesrna
#   build-native/bin/datatoc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build-native"
BLENDER_SRC="${PROJECT_ROOT}/Blender Mirror"

echo "[host-tools] Stage 1: Building native host tools"
echo "[host-tools] Blender source: ${BLENDER_SRC}"
echo "[host-tools] Build directory: ${BUILD_DIR}"

# Create build directory if it does not exist
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Configure with native cmake (NOT emcmake).
# Disable all features except the minimum needed for host tool compilation.
echo "[host-tools] Configuring CMake..."
cmake "${BLENDER_SRC}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_BLENDER=OFF \
    -DWITH_CYCLES=OFF \
    -DWITH_PYTHON=OFF \
    -DWITH_GHOST_SDL=OFF \
    -DWITH_GHOST_WAYLAND=OFF \
    -DWITH_GHOST_X11=OFF

# Build only the host tools needed for Stage 3 cross-compilation.
# makesdna: generates DNA type definitions (dna.cc, dna_type_offsets.h)
# makesrna: generates RNA reflection/Python API bindings
# datatoc: converts data files to C arrays for embedding
echo "[host-tools] Building makesdna, makesrna, datatoc..."
ninja makesdna makesrna datatoc

# Verify the built executables exist and print their paths
echo "[host-tools] Verifying built executables..."
for tool in makesdna makesrna datatoc; do
    TOOL_PATH=$(find "${BUILD_DIR}" -name "${tool}" -type f -executable 2>/dev/null | head -1)
    if [ -n "${TOOL_PATH}" ]; then
        echo "[host-tools] FOUND: ${TOOL_PATH}"
    else
        echo "[host-tools] ERROR: ${tool} not found after build" >&2
        exit 1
    fi
done

echo "[host-tools] Stage 1 complete. Host tools built successfully."
