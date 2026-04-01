# Testing Patterns

**Analysis Date:** 2026-04-01

## Test Framework

**C++ Testing:**
- Runner: Google Test (gtest) via CTest
- Header: `#include "testing/testing.h"`
- Config: `CMakeLists.txt` in test directories
- Integration: Tests compiled as separate executables integrated with CMake

**Python Testing:**
- Runner: unittest (standard library)
- Config: CMake configuration for test discovery and execution in `/tests/CMakeLists.txt`
- Launch: Via Blender executable with `--background --factory-startup --python-exit-code 1` parameters
- Modules: Custom test modules imported at runtime (e.g., `io_report` module)

**Run Commands:**

```bash
# C++: Run tests via ctest (configured in CMakeLists.txt)
ctest . --output-on-failure
ctest . -C [config] -O [logfile]  # With config and output redirection

# Python: Run tests via Blender with test script
blender --background --factory-startup --debug-memory --debug-exit-on-error --python-exit-code 1 --python test_file.py
```

## Test File Organization

**Location Patterns:**
- C++ tests: Co-located with implementation, in `/tests` subdirectory (e.g., `source/blender/asset_system/tests/`)
- Python tests: Centralized in `/tests/python/` directory
- Test data files: `/tests/files/` for test fixtures and expected outputs

**Naming Conventions:**
- C++ tests: `*_test.cc` (e.g., `asset_catalog_path_test.cc`, `asset_library_service_test.cc`)
- Python tests: Descriptive names with test prefix/suffix (e.g., `io_obj_import_test.py`, `bl_blendfile_header.py`)
- Test methods in classes: `test_*` prefix (e.g., `test_small_bhead_8`, `test_import_obj`)

**Directory Structure:**

```
source/blender/[module]/
├── tests/
│   ├── CMakeLists.txt
│   ├── [module]_test.cc
│   ├── [module]_another_test.cc
│   └── ...

tests/python/
├── bl_*.py           # Blender-specific tests
├── io_*_test.py      # Import/export tests
├── compositing_*.py
└── ...

tests/files/
├── layers/           # Layer test data
├── blender_project/  # Project file tests
├── io_tests/         # I/O test files
└── ...
```

## Test Structure

**C++ Test Pattern:**

```cpp
#include "testing/testing.h"

namespace blender::asset_system::tests {

TEST(AssetCatalogPathTest, construction)
{
  AssetCatalogPath default_constructed;
  EXPECT_EQ(default_constructed.str(), "");

  AssetCatalogPath from_char_literal("the/path");
  EXPECT_EQ(from_char_literal, "the/path");
}

TEST(AssetCatalogPathTest, length)
{
  const AssetCatalogPath one("1");
  EXPECT_EQ(1, one.length());
}

}  // namespace blender::asset_system::tests
```

**Python Test Pattern:**

```python
import pathlib
import unittest

import bpy

args = None  # Global test arguments

class OBJImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Called once before all tests in class."""
        cls.testdir = args.testdir
        cls.output_dir = args.outdir

    def setUp(self):
        """Called before each test method."""
        self.assertTrue(self.testdir.exists(),
                        "Test dir {0} should exist".format(self.testdir))

    def test_import_obj(self):
        """Test OBJ file import functionality."""
        input_files = sorted(pathlib.Path(self.testdir).glob("*.obj"))

        for input_file in input_files:
            with self.subTest(pathlib.Path(input_file).stem):
                bpy.ops.wm.open_mainfile(filepath=str(self.testdir / "../empty.blend"))
                ok = report.import_and_check(
                    input_file,
                    lambda filepath, params: bpy.ops.wm.obj_import(filepath=str(input_file), **params))
                if not ok:
                    self.fail(f"{input_file.stem} import result does not match expectations")

def main():
    global args
    import argparse

    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--testdir', required=True, type=pathlib.Path)
    parser.add_argument('--outdir', required=True, type=pathlib.Path)
    args, remaining = parser.parse_known_args()

    unittest.main(argv=[sys.argv[0]] + remaining)

if __name__ == "__main__":
    main()
```

**Patterns:**
- Test setup via `setUpClass()` for class-level initialization (runs once)
- Test setup via `setUp()` for per-test initialization (runs before each test)
- Test methods prefixed with `test_`
- Assertions using `EXPECT_*` macros (C++) or `assertEqual`, `assertTrue`, etc. (Python)
- Context managers with `with self.subTest(name):` for iterating test cases
- Global `args` variable for test configuration
- Custom test modules imported via `from modules import io_report`

## Mocking

**Framework:**
- C++: Uses real objects (test-friendly design rather than mocking framework)
- Python: Custom test utilities and modules (e.g., `io_report` module)

**Patterns:**

**C++ Pattern (Real Objects):**
```cpp
TEST(AssetCatalogPathTest, construction)
{
  AssetCatalogPath default_constructed;
  AssetCatalogPath from_char_literal("the/path");

  // Direct object construction and assertion
  EXPECT_EQ(default_constructed.str(), "");
  EXPECT_EQ(from_char_literal, "the/path");
}
```

**Python Pattern (Custom Modules):**
```python
from modules import io_report

report = io_report.Report("OBJ Import", self.output_dir, self.testdir, self.testdir.joinpath("reference"))

ok = report.import_and_check(
    input_file,
    lambda filepath, params: bpy.ops.wm.obj_import(filepath=str(input_file), **params))
```

**What to Mock:**
- File I/O: Provide test files in `tests/files/`
- External operations: Use Blender's bpy.ops API
- Custom modules: Import from `modules/` directory for shared test utilities

**What NOT to Mock:**
- Core Blender functionality (use real bpy API)
- File system operations (use actual test files)
- Rendering/display operations (use headless `--background` mode)

## Fixtures and Factories

**Test Data:**

**C++ Fixtures (from asset_catalog_path_test.cc):**
```cpp
const AssetCatalogPath empty("");
const AssetCatalogPath the_path("the/path");
const AssetCatalogPath the_path_child("the/path/child");
const AssetCatalogPath unrelated_path("unrelated/path");

// Direct construction in test methods for simplicity
```

**Python Fixtures (from io_obj_import_test.py):**
```python
input_files = sorted(pathlib.Path(self.testdir).glob("*.obj"))

for input_file in input_files:
    with self.subTest(pathlib.Path(input_file).stem):
        # Test data loaded from filesystem
        bpy.ops.wm.open_mainfile(filepath=str(self.testdir / "../empty.blend"))
```

**Location:**
- Test files (fixtures): `tests/files/` subdirectories organized by category
  - `tests/files/layers/` - layer test data
  - `tests/files/blender_project/` - project files
  - `tests/files/io_tests/obj/` - import/export test data
- Reference data: `tests/files/[test_type]/reference/` for output comparison
- Test utilities: `tests/python/modules/` for custom helper modules

## Coverage

**Requirements:**
- No enforced coverage threshold mentioned in configuration
- Tests integrated with CMake CTest system

**View Coverage:**
```bash
# C++ tests generate output logs
ctest . -O tests/log.txt         # Default config
ctest . -C [config] -O tests/log_[config].txt  # With specific config

# Python test results written to output directory
python test_file.py --testdir=/path --outdir=/path
```

**Coverage Files:**
- Test output logs: `tests/log.txt`, `tests/log_[config].txt`
- Test reports: Output directory specified via `--outdir` parameter in Python tests
- Reference comparison: `tests/files/[category]/reference/` files

## Test Types

**Unit Tests:**
- C++: Individual class/function tests with Google Test
- Python: Single-file import/feature tests with unittest
- Scope: Test individual components in isolation
- Example: `asset_catalog_path_test.cc` tests construction, length, name operations

**Integration Tests:**
- C++: Tests that verify multiple components working together
- Python: Full file import/export workflows
- Scope: Test Blender API interactions
- Example: `io_obj_import_test.py` tests complete OBJ import with Blender operations
- Approach: Uses real Blender executable with `--background --factory-startup`

**E2E Tests:**
- Framework: Python scripts running via Blender in headless mode
- Not separate from integration tests in this codebase
- Full workflow tests: open file, execute operation, compare results
- Example: Layer system tests create empty project, perform operations, validate state

## Common Patterns

**Async/Operation Testing (Python):**

```python
def test_import_obj(self):
    """Test OBJ file import."""
    # Open empty project
    bpy.ops.wm.open_mainfile(filepath=str(self.testdir / "../empty.blend"))

    # Execute import operation
    bpy.ops.wm.obj_import(filepath=str(input_file), **params)

    # Verify results via custom report
    ok = report.import_and_check(input_file, lambda filepath, params: bpy.ops.wm.obj_import(...))

    if not ok:
        self.fail(f"{input_file.stem} import result does not match expectations")
```

**Assertion Patterns (C++):**

```cpp
// Equality
EXPECT_EQ(value, expected);
EXPECT_NE(value, unexpected);

// Comparison
EXPECT_LT(a, b);
EXPECT_LE(a, b);
EXPECT_GT(a, b);
EXPECT_GE(a, b);

// Boolean
EXPECT_TRUE(condition);
EXPECT_FALSE(condition);

// With custom message
EXPECT_EQ(value, expected) << "Custom error message";

// Direct assertion in test
ASSERT_EQ(value, expected);  // Stops test on failure
```

**Error/Exception Testing (Python):**

```python
try:
    line = sc.history[-1].body
except:
    return {'CANCELLED'}

# Bare except allowed (E722 disabled in pyproject.toml)
```

**File System Testing (Python):**

```python
@classmethod
def setUpClass(cls):
    cls.testdir = args.testdir

def setUp(self):
    self.assertTrue(self.testdir.exists(),
                    "Test dir {0} should exist".format(self.testdir))

# Test data accessed via pathlib
input_files = sorted(pathlib.Path(self.testdir).glob("*.obj"))
```

## CMake Test Integration

**Configuration (from tests/CMakeLists.txt):**
```cmake
# Standard test execution parameters
set(TEST_BLENDER_EXE_PARAMS
  --background
  --factory-startup
  --debug-memory
  --debug-exit-on-error
  --python-exit-code 1
)

# Disable thumbnail creation for faster tests
set(TEST_BLENDER_EXE_PARAMS_NO_THUMB
  --python-expr [=[import bpy\;bpy.context.preferences.filepaths.file_preview_type='NONE']=]
)

# Python test execution
if(WITH_BLENDER AND WITH_PYTHON AND NOT WITH_PYTHON_MODULE)
  add_subdirectory(python)
endif()

# C++ test execution (Google Test)
# add_subdirectory(gtests)
```

**Test Command Format:**
```bash
add_blender_test(test_name "${TEST_BLENDER_EXE}" "${TEST_BLENDER_EXE_PARAMS}" [test_script.py])
```

---

*Testing analysis: 2026-04-01*
