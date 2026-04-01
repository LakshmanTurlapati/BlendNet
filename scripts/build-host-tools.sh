#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Stage 1 of the three-stage Blender WASM build pipeline.
#
# Builds native host tools (makesdna, datatoc) that are required
# during Blender's cross-compilation to WASM. These tools are code generators
# that must run on the host machine, not in the WASM target environment.
#
# This uses a standalone CMakeLists.txt (cmake/host_tools/CMakeLists.txt)
# that bypasses Blender's full build system to avoid platform-specific
# precompiled library dependencies (e.g., macOS lib/macos_arm64).
#
# Usage:
#   ./scripts/build-host-tools.sh
#
# Output:
#   build-native/makesdna
#   build-native/datatoc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build-native"
BLENDER_SRC="${PROJECT_ROOT}/Blender Mirror"
HOST_TOOLS_CMAKE="${PROJECT_ROOT}/cmake/host_tools/CMakeLists.txt"

echo "[host-tools] Stage 1: Building native host tools"
echo "[host-tools] Blender source: ${BLENDER_SRC}"
echo "[host-tools] Build directory: ${BUILD_DIR}"

# Verify the standalone host tools CMake exists
if [ ! -f "${HOST_TOOLS_CMAKE}" ]; then
    echo "[host-tools] ERROR: cmake/host_tools/CMakeLists.txt not found" >&2
    exit 1
fi

# Create build directory if it does not exist
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Configure with native cmake using the standalone host tools CMakeLists.txt.
# This avoids Blender's full build system which requires platform-specific
# precompiled libraries that may not be available.
echo "[host-tools] Configuring CMake (standalone host tools)..."
cmake "${PROJECT_ROOT}/cmake/host_tools" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBLENDER_SRC="${BLENDER_SRC}"

# Build the host tools
echo "[host-tools] Building makesdna, datatoc..."
ninja -j$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

# Verify the built executables exist and print their paths
echo "[host-tools] Verifying built executables..."
for tool in makesdna datatoc; do
    TOOL_PATH="${BUILD_DIR}/${tool}"
    if [ -x "${TOOL_PATH}" ]; then
        echo "[host-tools] FOUND: ${TOOL_PATH} ($(file -b "${TOOL_PATH}" | head -c 40))"
    else
        echo "[host-tools] ERROR: ${tool} not found or not executable at ${TOOL_PATH}" >&2
        exit 1
    fi
done

echo "[host-tools] Stage 1 complete. Host tools built successfully."
