# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Reproducible Emscripten build environment for Blender WASM compilation.
# This image provides the toolchain only -- builds are run via mounted volumes.

FROM emscripten/emsdk:5.0.4

LABEL maintainer="Blender Web Authors"
LABEL description="Emscripten 5.0.4 build environment for Blender WASM"
LABEL version="1.0"

# Install additional build tools required by Blender's build system.
# ninja-build: fast incremental builds (5-10x faster than Make on 4.4M lines)
# ccache: compilation caching to reduce rebuild times
# python3: required by Blender's build scripts
# brotli: WASM binary compression for serving
RUN apt-get update && apt-get install -y --no-install-recommends \
    ninja-build \
    ccache \
    python3 \
    brotli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy build configuration into the image
COPY cmake/ /src/cmake/
COPY scripts/ /src/scripts/

# Do NOT run builds in the Dockerfile -- it is for environment only.
# Builds are executed via docker-compose with mounted source volumes.
