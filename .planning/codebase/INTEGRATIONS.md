# External Integrations

**Analysis Date:** 2026-04-01

## APIs & External Services

**Blender Project Management (Gitea API):**
- Service: Gitea instance at `https://projects.blender.org/`
- What it's used for: Bug tracking, issue management, release notes generation
  - SDK/Client: Python `urllib` library (custom HTTP client)
  - Endpoint: `https://projects.blender.org/api/v1`
  - Examples: `release/release_notes/bug_fixes_per_major_release.py` queries issues for release notes
  - Auth: Public API access (no authentication required for public data)

**Documentation Versioning:**
- Service: External hosted versions JSON endpoint
- What it's used for: Documentation version switching on docs.blender.org
  - Endpoint: `https://docs.blender.org/PROD/versions.json`
  - Client: Vanilla JavaScript (doc/python_api/static/js/version_switch.js)
  - Usage: Version selector dropdown in documentation pages

**PyPI (Python Package Index):**
- Service: Official Python package repository
- What it's used for: Publishing bpy wheel (Python module for Blender)
  - Client: Custom Python upload script (`release/pypi/upload-release.py`)
  - Method: HTTP requests for package upload
  - Used by: `make bpy_wheel` build target

## Data Storage

**Databases:**
- No persistent database required - Blender is a standalone desktop/rendering application
- Blend file format (.blend) - Custom binary format for scene storage
  - Parser/Reader: Native C engine (in `source/blender/`)
  - File size: Complex projects can be multi-gigabyte

**File Storage:**
- Local filesystem only - All assets and scene files are local
- Blend file directory structure:
  - Datablocks (mesh, materials, textures, etc.)
  - Render caches
  - Compositor node setups
  - Animation keyframes

**Caching:**
- None - No external caching service
- Local disk caching for renders and baked simulations within blend files

## Authentication & Identity

**Auth Provider:**
- Custom/None - Blender is a standalone application with no built-in authentication
- PyPI authentication: Uses PyPI API tokens (`release/pypi/upload-release.py`)
  - Implementation: HTTP Basic Auth or token-based authentication for package uploads
- Gitea API: Public endpoints, no authentication for most operations

## Monitoring & Observability

**Error Tracking:**
- None integrated - Errors are logged locally to console/file

**Logs:**
- Console output - Standard stdout/stderr
- Build logs via CMake output
- Python script logging via logging module
- Render engine logs for Cycles GPU compilation

## CI/CD & Deployment

**Hosting:**
- Self-hosted Git server: `code.blender.org` (Gitea)
- GitHub mirrors: `https://github.com/blender/blender` (read-only)
- Documentation: `https://docs.blender.org/`

**CI Pipeline:**
- Gitea CI via custom workflow files (`.gitea/workflows/`)
- GitHub Actions (mirror synchronization only)
- Build farm for release binaries (not in source - infrastructure managed separately)

## Environment Configuration

**Required env vars:**
- `PYTHON_VERSION` - Python 3.13+ specification
- `CUDA_PATH` / `CUDA_HOME` - NVIDIA CUDA toolkit path (if `WITH_CYCLES_DEVICE_CUDA=ON`)
- `HIP_PATH` - AMD HIP toolkit path (if `WITH_CYCLES_DEVICE_HIP=ON`)
- `ONEAPI_ROOT` - Intel oneAPI toolkit path (if `WITH_CYCLES_DEVICE_ONEAPI=ON`)
- `OPTIX_ROOT_DIR` - NVIDIA OptiX SDK path (if `WITH_CYCLES_DEVICE_OPTIX=ON`)
- `BLENDER_PYTHON_SITE_PACKAGES` - Custom Python site-packages location (optional)

**Secrets location:**
- PyPI token: Typically in `~/.pypirc` or environment variable
- Git credentials: Standard Git credential storage or SSH keys
- No secrets stored in repository (proper git configuration)

## Webhooks & Callbacks

**Incoming:**
- None - Blender doesn't receive external webhooks

**Outgoing:**
- Release publishing to PyPI (one-way push)
- GitHub sync from Gitea (one-way mirror)
- Documentation builds trigger from source commits (infrastructure-managed)

## Build & Release Process Integrations

**Release Workflow:**
- `release/pypi/upload-release.py` - Uploads Python wheel distributions to PyPI
- `release/lts/lts_download.py` - Downloads LTS release artifacts
- `release/release_notes/bug_fixes_per_major_release.py` - Queries Gitea API to generate release notes from issue tracker

**File Format Integrations:**

**Import/Export Formats:**
- glTF 2.0 - 3D model interchange
- FBX - Autodesk format support
- Alembic - Animation cache format
- USD - Pixar Universal Scene Description
- OpenEXR - HDR image/sequence format
- WebP - Modern image compression
- JPEG, PNG, TIFF - Standard image formats
- SVG - Vector graphics (via NanoSVG)
- WAV, MP3, OGG - Audio formats
- FFmpeg-supported video codecs (H.264, H.265, ProRes, DNxHD, etc.)

## Rendering & GPU Integration

**NVIDIA GPU Support:**
- CUDA Compute - Direct GPU computation via CUDA runtime
  - Detection: `find_package(CUDA)` in CMakeLists.txt
  - Configuration: `WITH_CYCLES_DEVICE_CUDA` option
  - Binary caching: `WITH_CYCLES_CUDA_BINARIES` for offline kernel usage

- OptiX - Ray tracing via NVIDIA OptiX API
  - Configuration: `WITH_CYCLES_DEVICE_OPTIX` option
  - SDK path: `OPTIX_ROOT_DIR` environment variable

**AMD GPU Support:**
- HIP (Heterogeneous-compute Interface for Portability)
  - Configuration: `WITH_CYCLES_DEVICE_HIP` option
  - HIPRT ray tracing: `WITH_CYCLES_DEVICE_HIPRT` option

**Intel GPU Support:**
- oneAPI
  - Configuration: `WITH_CYCLES_DEVICE_ONEAPI` option

**Apple GPU Support:**
- Metal - Native Apple silicon GPU support
  - Configuration: `WITH_CYCLES_DEVICE_METAL` option
  - Always available on macOS (not optional)

**CPU Rendering:**
- Fallback CPU rendering always available
- OpenGL backend: `WITH_OPENGL_BACKEND` option

## Asset & Content Integrations

**Texture & Image Format Support:**
- OpenEXR - Professional HDR format with `WITH_IMAGE_OPENEXR`
- OpenJPEG - JPEG2000 support with `WITH_IMAGE_OPENJPEG`
- CINEON/DPX - Digital cinema formats with `WITH_IMAGE_CINEON`
- WebP - Modern compression with `WITH_IMAGE_WEBP`

**Geometry Format Support:**
- glTF (tinygltf) - Web 3D format
- FBX (ufbx) - Game engine interchange format
- Alembic - Animation sequence format
- USD - Pixar scene interchange format

**Material Support:**
- MaterialX - Open standard material definitions

## Platform-Specific Integrations

**Linux:**
- X11 - Display server support (`WITH_GHOST_X11`)
- Wayland - Modern display server (`WITH_GHOST_WAYLAND`)
- Wayland client-side decorations (CSD) - `WITH_GHOST_CSD`
- X11 Xinput - Tablet input support
- X11 XFixes - Cursor warping workaround

**macOS:**
- Cocoa framework - Window management
- QuickLook - Thumbnail extraction for Finder

**Windows:**
- DirectX/ANGLE - Graphics support
- Windows Explorer - Thumbnail integration via BlendThumb.dll
- Windows SDK integration

## Documentation & Build System Integrations

**Documentation Build:**
- Sphinx - Documentation generation system (Python-based)
- Doxygen - API documentation (C/C++)
- Version switching - Client-side JavaScript (`doc/python_api/static/js/version_switch.js`) fetches from `versions.json`

**Build Environment:**
- Pre-built libraries - Downloaded and cached in `build_files/build_environment/`
- Git LFS - Large file storage for binary assets (startup.blend, icons, etc.)
- Build configuration caching - CMake cache for faster rebuilds

---

*Integration audit: 2026-04-01*
