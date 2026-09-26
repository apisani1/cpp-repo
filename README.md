# C++23 / C23 Project Template

A C++23 template with C23 support built with CMake presets, Ninja, CTest, clang-format, clang-tidy,
cppcheck and llvm-cov. Warnings, sanitizers and coverage instrumentation apply
uniformly to the library, the executable and every test.

## Prerequisites

- CMake 3.28 or newer
- Ninja
- Xcode Command Line Tools, which provide Apple Clang, clangd, clang-format,
  llvm-profdata, llvm-cov and LLDB
- clang-tidy (required for `make tidy` and `make qa`)
- cppcheck (required for `make cppcheck` and `make qa`)
- doxygen (required for `make docs`): `brew install doxygen`

macOS-only by design: the presets pin `/usr/bin/clang`, `/usr/bin/clang++` and `CMAKE_OSX_SYSROOT`,
and tool discovery prefers Xcode's toolchain via `xcrun`. If Xcode lacks a tool
such as clang-tidy, install it separately (for example, Homebrew LLVM). Put
machine-specific overrides in `CMakeUserPresets.json`, which is gitignored.

## Start a project

```sh
make init NAME=Widget
make clean-all && make qa
```

`make init` rewrites the project name across `CMakeLists.txt`, `README.md`,
`CLAUDE.md` and `.vscode/`. Then replace the placeholder `greeting` module with
your own code.

## Layout

```
include/          Public headers for the core library
src/              Library sources, plus main.cpp (a thin wrapper only)
tests/            One test_*.c / test_*.cpp per test executable (Unity)
cmake/            CMake helper scripts
scripts/          init-project.sh
```

Application logic belongs in the core library (`<Project>_core`), which both the
executable and the tests link. Keeping `main.cpp` thin is what makes the code
testable.

## Language support

CMake enables C++23 and C23 with language extensions disabled. The sample
`src/main.cpp` uses the C library in `src/greeting.c`; `greeting.h` uses
`extern "C"` guards so both languages can include it. C and C++ tests exercise
that shared interface. C++-only headers can use `.hpp` and normal C++ linkage.

Add production `.c`, `.cc`, `.cpp` or `.cxx` files explicitly to the core target
in `CMakeLists.txt`. Test discovery and quality tools support all four extensions;
formatting also covers `.h`, `.hh`, `.hpp`, `.hxx`, `.inl` and `.tpp` headers.
Test filenames must have unique stems, such as `test_greeting.c` and
`test_greeting_cpp.cpp`. C-only prototype warnings are restricted to C sources.

## Adding a test

Tests use [Unity](https://github.com/ThrowTheSwitch/Unity), fetched automatically at
configure time — a clean build needs network access. Create `tests/test_<thing>.cpp` (or `.c` for a C test):

```cpp
#include "greeting.h"

#include "unity.h"

/* Required in every test file: each one is its own executable. */
void setUp(void) {}
void tearDown(void) {}

namespace {
void it_greets() {
    TEST_ASSERT_EQUAL_STRING("Hello, world!", greeting_text());
}
} // namespace

int main() {
    UNITY_BEGIN();
    RUN_TEST(it_greets);
    return UNITY_END();
}
```

It is globbed, built and registered with CTest automatically — no CMake edit needed.
Common assertions are `TEST_ASSERT_EQUAL_STRING`, `TEST_ASSERT_EQUAL_INT`,
`TEST_ASSERT_TRUE`, `TEST_ASSERT_NULL` and `TEST_ASSERT_NOT_NULL`; failures report both the
expected and the actual value. Unity's full assertion reference is in its docs.

## Common commands

```sh
make                                   # build + docs for the selected config (alias for 'make all')
make debug                             # configure + build Debug
make build                             # configure + build Release
make test                              # run the test suite
make lint                              # tidy and cppcheck
make qa                                # format-check, lint plus the build and the tests (alias: check)
make pre-commit                        # format, then tidy
make coverage                          # report + HTML under build/coverage/coverage-report/ (alias: test-cov)
make docs                              # API docs under build/debug/docs/html/
make install                           # install the executable under PREFIX (~/.local)
make uninstall                         # remove the files that 'make install' wrote
make CONFIG=<preset> run ARGS='...'    # build with <preset> and run the executable with arguments
make clean                             # remove the selected build directory
make clean-all                         # remove all build directories
```

`make cbuild` builds the current `CONFIG` without reconfiguring; it is the primitive the
other targets compose, and is what editor tasks and file watchers should call.

`make install` defaults to `PREFIX=$HOME/.local`, so it needs no `sudo` and puts the
executable in `~/.local/bin`. Pass `PREFIX` for anywhere else — a system-wide
`make install PREFIX=/usr/local` needs `sudo`, since that tree is root-owned. The default
applies to this Makefile only; `CMAKE_INSTALL_PREFIX` keeps CMake's usual `/usr/local`.

`make uninstall` reads the `install_manifest.txt` that `cmake --install` wrote under
`build/<config>/`, so it needs the build directory the install came from. It deletes only
the files listed there, never the directories that hold them. Note that the manifest
records only the most recent install, so installing to two different prefixes from one
build directory leaves the earlier copy orphaned.

`make help` lists every target with a one-line description.

`CONFIG` selects the preset: `debug` (default), `release`, `relwithdebinfo`,
`coverage`. Each has an independent build directory under `build/`.

`make qa` only checks formatting; it never rewrites source files. Use
`make format` to apply formatting intentionally.

## Documentation

`make docs` runs Doxygen and writes HTML to `build/debug/docs/html/`, using this README as
the landing page. The Doxyfile is generated from CMake rather than checked in, so the project
name keeps coming from the single `project()` call and `make init` needs no extra rewrite.

Document public declarations in `include/` with `@brief`, `@param` and `@return`; see
`include/greeting.h` for the expected style. `docs` is deliberately **not** part of
`make qa` — an undocumented function warns, it does not block the build. To make it a hard
gate, set `DOXYGEN_WARN_AS_ERROR` to `FAIL_ON_WARNINGS` in `CMakeLists.txt`.

On pushes to `main`, CI publishes the generated docs to GitHub Pages.

## Quality gates

`make qa` is a hard gate. It fails on clang-tidy findings
(`--warnings-as-errors=*`), on cppcheck findings (`--error-exitcode=1`), on
compiler warnings (`-Werror`), and on sanitizer findings
(`-fno-sanitize-recover=all`, so UBSan aborts rather than reporting and
continuing). Debug builds run under AddressSanitizer and UBSan, tests included.

The same gate runs in CI on `macos-latest` for both debug and release.
