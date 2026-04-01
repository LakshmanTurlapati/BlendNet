# Coding Conventions

**Analysis Date:** 2026-04-01

## Naming Patterns

**Files:**
- C/C++ files: snake_case (e.g., `asset_catalog.cc`, `asset_catalog.hh`, `creator.cc`)
- Python files: snake_case (e.g., `_bpy_restrict_state.py`, `_console_shell.py`, `make_test.py`)
- Header files: `.h` extension for C, `.hh` extension for C++
- Test files in C++: suffix with `_test.cc` (e.g., `asset_catalog_path_test.cc`, `asset_library_service_test.cc`)
- Test files in Python: prefix or suffix with test (e.g., `io_obj_import_test.py`, `bl_blendfile_header.py`)
- Private/internal modules in Python: prefix with underscore (e.g., `_bpy_types.py`, `_console_python.py`, `_rna_info.py`)

**Functions:**
- C/C++ functions: snake_case with descriptive verb-first names
- Python functions: snake_case, lowercase with underscores
- Class methods in Python: snake_case (e.g., `setUpClass`, `setUp`, `test_import_obj`)
- Private functions: prefix with underscore in Python

**Variables:**
- Local variables: snake_case
- Class attributes in C++: suffix with underscore (e.g., `_real_data`, `_real_pref`)
- Constants: UPPER_SNAKE_CASE
- Private class members: prefix with underscore

**Types:**
- C++ classes: CamelCase (e.g., `AssetCatalogPath`, `RestrictBlend`, `_RestrictContext`)
- C structs: CamelCase with leading letter (e.g., `BlendFileHeader`)
- Python classes: CamelCase (e.g., `BlendFileHeaderTest`, `OBJImportTest`, `Popover`)
- Enums and type definitions: CamelCase

## Code Style

**Formatting:**
- Tool: clang-format (C/C++) configured in `.clang-format`
- autopep8 (Python) configured in `pyproject.toml`
- Max line length: 99 characters for C/C++, 120 characters for Python
- Indentation: 2 spaces for C/C++, 4 spaces for Python and shell scripts
- Line ending: Unix-style with final newline required

**Key Formatting Rules (C/C++):**
- AlignAfterOpenBracket: parameters align to opening brace
- AllowShortBlocksOnASingleLine: false (no single-line blocks)
- BinPackArguments: false (stack parameters on separate lines)
- BinPackParameters: false (stack parameters on separate lines)
- ConstructorInitializerAllOnOnePerLine: true (one initializer per line)
- Function calls and definitions have parameters stacked when exceeding line limit

**Key Formatting Rules (Python):**
- Line length: maximum 120 characters
- Aggressive autopep8 level: 2
- Skip string normalization in black configuration
- Do not modify: E721 (type comparisons), E722 (bare except), E402 (module imports not at top)

**Linting:**
- C/C++: clang-tidy configured in `.clang-tidy`
- Python: autopep8 as primary formatter
- File configuration in `.editorconfig` specifies per-language rules

## EditorConfig Standards

All files use `.editorconfig` configuration:

**C/C++ (.c, .cc, .h, .hh, .inl, .glsl):**
- Charset: UTF-8
- Trim trailing whitespace: yes
- Insert final newline: yes
- Indent: 2 spaces
- Max line: 99 characters

**Python (.py):**
- Charset: UTF-8
- Trim trailing whitespace: yes
- Insert final newline: yes
- Indent: 4 spaces
- Max line: 120 characters

**CMake & Text (.cmake, .txt):**
- Charset: UTF-8
- Indent: 2 spaces
- Max line: 99 characters

## Import Organization

**C/C++ Includes (from `creator.cc` pattern):**
1. System includes (e.g., `<cstdlib>`, `<cstring>`, `<windows.h>`)
2. Platform-specific includes wrapped in conditionals
3. Internal library includes (BLI, BKE, DNA, etc.)
4. Module-specific includes
5. Comment blocks separating logical groups
6. Include guards with `#ifndef` style

**Python Imports (from test files pattern):**
1. Standard library imports (pathlib, sys, unittest, argparse)
2. Third-party imports (bpy)
3. Local module imports (relative or absolute)
4. Module variables and initialization after imports

**Include Patterns:**
- C++ uses `.hh` for header files
- C uses `.h` for header files
- Prefix system includes with `<>` for standard library
- Prefix local includes with `""` for project files
- Group related includes with comments (e.g., `/* Mostly initialization functions. */`)

## Error Handling

**C/C++ Patterns:**
- Returns status codes or boolean values for success/failure
- Null pointer checks before dereferencing
- Context manager pattern in C++ classes (constructor/destructor for RAII)
- CMake test parameters include `--debug-exit-on-error` and `--python-exit-code 1`

**Python Patterns:**
- Bare except blocks used where appropriate (E722 disabled for compatibility)
- Try-except blocks in utility functions
- Return dictionaries with status strings (e.g., `{'FINISHED'}`, `{'CANCELLED'}`)
- Global variables for test state (e.g., `args = None`) initialized at module level

**Comment-based Error Handling:**
- TODO comments for incomplete features (e.g., `# TODO` in shell.py)
- FIXME comments for known issues
- Comments explaining why certain linting rules are disabled

## Logging

**Framework:**
- C/C++: CLG_log (from `#include "CLG_log.h"`)
- Python: bpy.ops system and custom scrollback handling
- Shell/interactive: custom scrollback implementation via `add_scrollback()` function

**Patterns:**
- Console output styling in Python: 'OUTPUT', 'ERROR', 'INPUT' types
- Scrollback append for text rendering in interactive contexts
- Command output capture via subprocess.getstatusoutput()

## Comments

**When to Comment:**
- Explain non-obvious logic or workarounds
- Clarify disabled linting rules with justification
- Document special cases or exceptions
- Explain test expectations and assertions

**Documentation Comments:**
- C/C++ uses `/** \file` style documentation
- Python docstrings for modules (e.g., `"""This module contains RestrictBlend context manager."""`)
- Comments use SPDX license identifiers at file top
- `\ingroup` and `\file` tags in C/C++ for Doxygen compatibility

**License Headers:**
- All files start with SPDX-FileCopyrightText and SPDX-License-Identifier
- Format: `# SPDX-FileCopyrightText: YYYY-YYYY Blender Authors`
- Format: `# SPDX-License-Identifier: GPL-2.0-or-later`
- C/C++ uses `/* */` style, Python uses `#` style

## Function Design

**Size:**
- Functions kept reasonably small for testability
- Complex logic broken into helper functions
- Methods like `test_*` in test classes dedicated to single test scenario

**Parameters:**
- C/C++: parameters stacked on separate lines when exceeding line limit
- Python: positional and keyword arguments used naturally
- Test methods accept `self` only (test data comes from `setUpClass`/`setUp`)
- Unused parameters prefixed with underscore (e.g., `_is_interactive`, `_type`, `_value`, `_traceback`)

**Return Values:**
- C/C++: void functions for side effects, return status/values for results
- Python test methods: return nothing (side effects via assertions)
- Utility functions: return data structures or status dictionaries

## Module Design

**Exports:**
- Python modules use `__all__` tuple to define public API (e.g., from `_bpy_restrict_state.py`: `__all__ = ("RestrictBlend",)`)
- C/C++: header files define public API, implementation in .c or .cc files
- Private modules in Python use leading underscore prefix

**Barrel Files:**
- Not commonly used in this project
- Imports are explicit and direct to source modules

**Namespaces:**
- C++ uses nested namespaces for organization (e.g., `blender::asset_system::tests`)
- Python uses module structure for organization

---

*Convention analysis: 2026-04-01*
