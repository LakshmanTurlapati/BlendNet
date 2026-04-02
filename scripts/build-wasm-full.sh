#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# End-to-end Blender WASM build orchestrator.
#
# Runs inside Docker to produce blender.wasm, blender.wasm.br, and blender.js.
# Handles the full pipeline: deps, native host tools, CMake config, ninja patch,
# WASM compilation, and Brotli compression.
#
# Usage (from host machine):
#   docker compose run --rm blender-wasm-build bash scripts/build-wasm-full.sh
#
# The script is designed to be idempotent -- rerunning picks up where it left off
# thanks to ninja's incremental build support.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build-wasm"
NATIVE_DIR="${PROJECT_ROOT}/build-native"
BLENDER_SRC="${PROJECT_ROOT}/Blender Mirror"
CMAKE_DIR="${PROJECT_ROOT}/cmake"
WASM_BUILD_MODE="${WASM_BUILD_MODE:-Release}"
WASM_DEBUG_TRAP="${WASM_DEBUG_TRAP:-0}"

BUILD_START_TIME=$(date +%s)

detect_jobs() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4
}

log() {
    echo "[$(date -u '+%H:%M:%S')] $*"
}

format_mb() {
    local bytes="${1:?missing byte count}"
    awk -v bytes="${bytes}" 'BEGIN { printf "%.2f", bytes / 1048576 }'
}

format_minutes() {
    local seconds="${1:?missing second count}"
    awk -v seconds="${seconds}" 'BEGIN { printf "%.1f", seconds / 60 }'
}

sync_wasm_artifact() {
    local src="${1:?missing source}"
    local dst="${2:?missing destination}"

    if [ ! -f "${src}" ]; then
        return 1
    fi

    cp "${src}" "${dst}"
    return 0
}

fail() {
    log "FAILED at stage: $1"
    log "Error: $2"
    log "Suggestion: $3"
    exit 1
}

run_with_retry() {
    local attempts="${1:?missing retry attempts}"
    local delay_seconds="${2:?missing retry delay}"
    shift 2

    local attempt=1
    while true; do
        if "$@"; then
            return 0
        fi

        if [ "${attempt}" -ge "${attempts}" ]; then
            return 1
        fi

        attempt=$((attempt + 1))
        log "Retrying command (${attempt}/${attempts}) after ${delay_seconds}s: $*"
        sleep "${delay_seconds}"
    done
}

log "=========================================="
log "Blender WASM Full Build Pipeline"
log "=========================================="
log "Blender source: ${BLENDER_SRC}"
log "Build dir (WASM): ${BUILD_DIR}"
log "Build dir (native): ${NATIVE_DIR}"
log "Build mode: ${WASM_BUILD_MODE}"
log "Trap diagnostics: ${WASM_DEBUG_TRAP}"

# ==========================================================================
# Stage 1: Install dependencies
# ==========================================================================
log ""
log "=== Stage 1: Dependencies ==="

if [ -f "${PROJECT_ROOT}/scripts/setup-wasm-deps.sh" ]; then
    log "Running setup-wasm-deps.sh..."
    bash "${PROJECT_ROOT}/scripts/setup-wasm-deps.sh" || \
        fail "setup-wasm-deps" "Dependency installation failed" "Check network connectivity and apt sources"
    log "Dependencies installed."
else
    fail "setup-wasm-deps" "scripts/setup-wasm-deps.sh not found" "Ensure project is correctly mounted"
fi

# ==========================================================================
# Stage 1b: Apply tracked source compatibility patches
# ==========================================================================
log ""
log "=== Stage 1b: Source Compatibility Patches ==="

for patch_file in "${PROJECT_ROOT}"/patches/*.wasm32.patch; do
    if [ ! -f "${patch_file}" ]; then
        continue
    fi

    patch_name="$(basename "${patch_file}")"
    if git -C "${BLENDER_SRC}" apply --reverse --check "${patch_file}" >/dev/null 2>&1; then
        log "Patch already applied: ${patch_name}"
        continue
    fi

    log "Applying source patch: ${patch_name}"
    git -C "${BLENDER_SRC}" apply "${patch_file}" || \
        fail "source-patch" "Failed to apply ${patch_name}" "Check Blender Mirror patch drift or local source changes"
done

# Install additional packages needed for host tool compilation and headers
log "Installing additional system packages (sse2neon, Eigen3)..."

# sse2neon: ARM NEON stub for SSE intrinsics (Blender uses SSE in some headers)
SYSROOT=/emsdk/upstream/emscripten/cache/sysroot
if [ ! -f "${SYSROOT}/include/sse2neon.h" ]; then
    cd /tmp && rm -rf sse2neon
    git clone --depth 1 https://github.com/DLTcollab/sse2neon.git 2>&1 | tail -1
    cp /tmp/sse2neon/sse2neon.h "${SYSROOT}/include/"
    log "sse2neon: installed to sysroot"
else
    log "sse2neon: already in sysroot"
fi

# Eigen3: header-only linear algebra library
# Must use the exact commit Blender expects (development branch, not a release tag)
# Using tarball download instead of git clone for speed
EIGEN_COMMIT="8a1083e9bf41b91fdea6546681f806154efdc25a"
if [ ! -d "${SYSROOT}/include/Eigen" ]; then
    cd /tmp && rm -rf eigen eigen-${EIGEN_COMMIT}*
    log "Downloading Eigen3 (commit ${EIGEN_COMMIT:0:7})..."
    wget -q "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_COMMIT}/eigen-${EIGEN_COMMIT}.tar.gz" -O /tmp/eigen.tar.gz
    tar xzf /tmp/eigen.tar.gz -C /tmp
    EIGEN_DIR=$(ls -d /tmp/eigen-${EIGEN_COMMIT}* 2>/dev/null | head -1)
    if [ -z "${EIGEN_DIR}" ]; then
        log "ERROR: Failed to extract Eigen3 tarball"
        exit 1
    fi
    cp -r "${EIGEN_DIR}/Eigen" "${SYSROOT}/include/"
    cp -r "${EIGEN_DIR}/unsupported" "${SYSROOT}/include/" 2>/dev/null || true
    mkdir -p "${SYSROOT}/share/eigen3/cmake"
    cp "${EIGEN_DIR}/cmake/Eigen3Config.cmake" "${SYSROOT}/share/eigen3/cmake/" 2>/dev/null || true
    rm -f /tmp/eigen.tar.gz
    log "Eigen3: installed to sysroot (commit ${EIGEN_COMMIT:0:7})"
else
    log "Eigen3: already in sysroot"
fi

# Also make sse2neon available for host tools via /usr/include
if [ ! -f /usr/include/sse2neon.h ] && [ -f "${SYSROOT}/include/sse2neon.h" ]; then
    cp "${SYSROOT}/include/sse2neon.h" /usr/include/ 2>/dev/null || true
fi

# ==========================================================================
# Stage 2: Build native host tools with GCC-14
# ==========================================================================
log ""
log "=== Stage 2: Native Host Tools + Node.js ==="

# Hybrid strategy:
# - makesdna + makesrna: link as WASM and run through node for wasm32-correct
#   DNA/RNA generation
# - datatoc + shader_tool: build natively with GCC-14

# Install fmt headers for host tools
if [ ! -f /usr/include/fmt/format.h ]; then
    log "Installing fmt headers..."
    if [ -d /tmp/fmt/include/fmt ]; then
        cp -r /tmp/fmt/include/fmt /usr/include/
    else
        cd /tmp && rm -rf fmt
        git clone --depth 1 --branch 11.1.4 https://github.com/fmtlib/fmt.git 2>&1 | tail -1
        cp -r /tmp/fmt/include/fmt /usr/include/
    fi
fi

export CC=gcc-14
export CXX=g++-14
log "Building native host tools with CC=${CC} CXX=${CXX}..."
bash "${PROJECT_ROOT}/scripts/build-host-tools.sh" || \
    fail "host-tools" "Native host tools build failed" "Check GCC-14 availability"

for tool in makesdna datatoc shader_tool; do
    if [ -x "${NATIVE_DIR}/${tool}" ]; then
        log "FOUND: ${NATIVE_DIR}/${tool}"
    else
        log "WARNING: ${tool} not found at ${NATIVE_DIR}/${tool}"
    fi
done

# Also ensure Node.js is available for makesrna WASM execution.
if ! command -v node &>/dev/null; then
    log "Installing Node.js..."
    apt-get update -qq && apt-get install -y -qq nodejs 2>&1 | tail -3
fi
log "Node.js: $(node --version 2>/dev/null || echo 'not available')"

# ==========================================================================
# Stage 3: Verify Emscripten ports
# ==========================================================================
log ""
log "=== Stage 3: Emscripten Ports ==="

# Source emsdk environment
source /emsdk/emsdk_env.sh 2>/dev/null || true

if [ -f "${PROJECT_ROOT}/scripts/build-wasm-deps.sh" ]; then
    log "Running build-wasm-deps.sh..."
    run_with_retry 3 5 bash "${PROJECT_ROOT}/scripts/build-wasm-deps.sh" || \
        fail "wasm-deps" "Emscripten port verification failed" "Check emcc is working"
    log "Emscripten ports verified."
fi

# ==========================================================================
# Stage 4: CMake Configuration (emcmake)
# ==========================================================================
log ""
log "=== Stage 4: CMake Configuration ==="

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Reconfigure when the initial cache inputs or CMake shim files change.
needs_reconfigure=0
if [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
    needs_reconfigure=1
else
    if ! grep -q "^CMAKE_BUILD_TYPE:STRING=${WASM_BUILD_MODE}$" "${BUILD_DIR}/CMakeCache.txt"; then
        needs_reconfigure=1
    fi

    if [ "${needs_reconfigure}" -eq 0 ] && \
        ! grep -q "^BLENDER_WEB_WASM_TRAP_DEBUG:STRING=${WASM_DEBUG_TRAP}$" "${BUILD_DIR}/CMakeCache.txt"; then
        needs_reconfigure=1
    fi

    for input in \
        "${CMAKE_DIR}/emscripten_overrides.cmake" \
        "${CMAKE_DIR}/wasm_sources.cmake" \
        "${PROJECT_ROOT}/source/wasm_headless_main.cc" \
        "${PROJECT_ROOT}/scripts/build-wasm-full.sh" \
        "${PROJECT_ROOT}/scripts/build-wasm.sh"; do
        if [ "${input}" -nt "${BUILD_DIR}/CMakeCache.txt" ]; then
            needs_reconfigure=1
            break
        fi
    done

    if [ "${needs_reconfigure}" -eq 0 ] && \
        find "${CMAKE_DIR}/fake_modules" "${CMAKE_DIR}/stubs" -type f -newer "${BUILD_DIR}/CMakeCache.txt" \
            | grep -q .; then
        needs_reconfigure=1
    fi

    if [ "${needs_reconfigure}" -eq 0 ] && \
        find "${PROJECT_ROOT}/patches" -type f -name '*.wasm32.patch' -newer "${BUILD_DIR}/CMakeCache.txt" \
            | grep -q .; then
        needs_reconfigure=1
    fi
fi

if [ "${needs_reconfigure}" -eq 1 ]; then
    log "Running emcmake cmake..."
    emcmake cmake "${BLENDER_SRC}" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE="${WASM_BUILD_MODE}" \
        -C "${CMAKE_DIR}/emscripten_overrides.cmake" \
        -C "${CMAKE_DIR}/wasm_sources.cmake" \
        -DCMAKE_MODULE_PATH="${CMAKE_DIR}/fake_modules" \
        -DWITH_LIBS_PRECOMPILED=OFF \
        \
        -DWITH_HEADLESS=ON \
        -DWITH_BLENDER=ON \
        \
        -DWITH_BULLET=ON \
        -DWITH_IK_SOLVER=ON \
        -DWITH_IK_ITASC=ON \
        -DWITH_MOD_REMESH=ON \
        \
        -DWITH_PYTHON=OFF \
        -DWITH_BLENDER_THUMBNAILER=OFF \
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
        -DWITH_CYCLES_DEVICE_METAL=OFF \
        -DWITH_STATIC_LIBS=OFF \
        -DWITH_IMAGE_OPENJPEG=OFF \
        -DWITH_CODEC_SNDFILE=OFF \
        -DWITH_IO_STL=OFF \
        -DWITH_IO_WAVEFRONT_OBJ=OFF \
        -DWITH_IO_PLY=OFF \
        -DWITH_COMPILER_ASAN=OFF \
        -DWITH_HARFBUZZ=OFF \
        -DWITH_FRIBIDI=OFF \
        -DWITH_IMAGE_WEBP=OFF \
        -DWITH_SYSTEM_FREETYPE=OFF \
        -DWITH_COMPILER_SIMD=OFF \
        -DWITH_LIBMV=OFF \
        -DWITH_MATERIALX=OFF \
        -DWITH_INPUT_NDOF=OFF \
        -DWITH_QUADRIFLOW=OFF \
        || fail "cmake-config" "CMake configuration failed" "Check CMake output above"

    rm -f "${BUILD_DIR}/build.ninja.orig"
    log "CMake configuration complete."
else
    log "CMakeCache.txt exists, skipping reconfiguration."
    log "No newer CMake inputs detected."
fi

# ==========================================================================
# Stage 5: Patch build.ninja for host tool cross-compilation
# ==========================================================================
log ""
log "=== Stage 5: Patching build.ninja ==="

if [ ! -f "${BUILD_DIR}/build.ninja" ]; then
    fail "patch-ninja" "build.ninja not found" "CMake configuration may have failed"
fi

bash "${PROJECT_ROOT}/scripts/patch-ninja-host-tools.sh" "${BUILD_DIR}" "${NATIVE_DIR}" || \
    fail "patch-ninja" "Ninja patching failed" "Check patch-ninja-host-tools.sh output"

log "build.ninja patched successfully."

# ==========================================================================
# Stage 6: WASM Compilation
# ==========================================================================
log ""
log "=== Stage 6: WASM Compilation ==="

cd "${BUILD_DIR}"

# Ensure emsdk environment is loaded
source /emsdk/emsdk_env.sh 2>/dev/null || true

COMPILE_START=$(date +%s)
JOBS="$(detect_jobs)"
log "Starting WASM compilation with ${JOBS} cores..."

# Run the actual WASM build
emmake ninja -j"${JOBS}" 2>&1 || {
    NINJA_EXIT=$?
    log "WARNING: ninja exited with code ${NINJA_EXIT}"
    log "Some targets may have failed. Checking for output artifacts..."
}

COMPILE_END=$(date +%s)
COMPILE_DURATION=$((COMPILE_END - COMPILE_START))
log "Compilation phase took ${COMPILE_DURATION} seconds."

# ==========================================================================
# Stage 7: Post-Build (compression and validation)
# ==========================================================================
log ""
log "=== Stage 7: Post-Build ==="

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

sync_wasm_artifact "${BUILD_DIR}/bin/blender.wasm" "${BUILD_DIR}/blender.wasm" || true
sync_wasm_artifact "${BUILD_DIR}/bin/blender.js" "${BUILD_DIR}/blender.js" || true

if [ -f "${BUILD_DIR}/blender.wasm" ]; then
    WASM_SIZE=$(stat -c%s "${BUILD_DIR}/blender.wasm" 2>/dev/null || stat -f%z "${BUILD_DIR}/blender.wasm" 2>/dev/null)
    WASM_MB="$(format_mb "${WASM_SIZE}")"
    log "blender.wasm: ${WASM_SIZE} bytes (${WASM_MB} MB)"

    # Brotli compression
    if command -v brotli &>/dev/null; then
        log "Compressing with Brotli (--best)..."
        brotli --best --force "${BUILD_DIR}/blender.wasm" -o "${BUILD_DIR}/blender.wasm.br"
        BR_SIZE=$(stat -c%s "${BUILD_DIR}/blender.wasm.br" 2>/dev/null || stat -f%z "${BUILD_DIR}/blender.wasm.br" 2>/dev/null)
        BR_MB="$(format_mb "${BR_SIZE}")"
        log "blender.wasm.br: ${BR_SIZE} bytes (${BR_MB} MB)"

        BR_INT_MB=$((BR_SIZE / 1048576))
        if [ "${BR_INT_MB}" -gt 30 ]; then
            log "WARNING: Compressed size exceeds 30MB target (${BR_MB} MB)"
        else
            log "PASS: Compressed size within 30MB target (${BR_MB} MB)"
        fi
    else
        log "WARNING: brotli not found, skipping compression"
    fi

    if [ -f "${BUILD_DIR}/blender.js" ]; then
        JS_SIZE=$(stat -c%s "${BUILD_DIR}/blender.js" 2>/dev/null || stat -f%z "${BUILD_DIR}/blender.js" 2>/dev/null)
        log "blender.js: ${JS_SIZE} bytes"
    fi

    log ""
    log "=========================================="
    log "BUILD SUCCEEDED"
    log "=========================================="
    log "Total build time: ${BUILD_DURATION} seconds ($(format_minutes "${BUILD_DURATION}") min)"
    log "Artifacts:"
    ls -lh "${BUILD_DIR}/blender.wasm" "${BUILD_DIR}/blender.wasm.br" "${BUILD_DIR}/blender.js" 2>/dev/null
else
    log ""
    log "=========================================="
    log "BUILD INCOMPLETE - blender.wasm not produced"
    log "=========================================="
    log "Total time: ${BUILD_DURATION} seconds"
    log ""
    log "Checking what was built..."
    if ls "${BUILD_DIR}"/bin/* 2>/dev/null; then
        log "Host tool binaries in bin/:"
        ls -lh "${BUILD_DIR}"/bin/ 2>/dev/null
    fi
    log ""
    log "Last ninja errors (if any):"
    # Show the ninja log for debugging
    if [ -f "${BUILD_DIR}/.ninja_log" ]; then
        tail -20 "${BUILD_DIR}/.ninja_log"
    fi
    log ""
    log "To debug: docker compose run --rm blender-wasm-build bash"
    log "Then: cd /src/build-wasm && ninja -j1 2>&1 | tail -50"
    exit 1
fi
