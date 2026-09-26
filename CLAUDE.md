# CLAUDE.md — MyProject

C23 project built with CMake presets, Ninja, CTest, clang-format, clang-tidy and cppcheck.

@./notes

## Layout

| Path                  | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `include/`            | Public headers for the core library                            |
| `src/`                | Library sources, plus `main.c` (a thin wrapper only)           |
| `tests/`              | One `test_*.c` per test executable (Unity)                     |
| `cmake/`              | CMake helper scripts (`RunCoverage.cmake`)                     |
| `scripts/`            | `init-project.sh` — one-time template rename                   |

## Conventions

- **All logic goes in the core library** (`MyProject_core`), not in `src/main.c`.
  `main.c` stays a thin wrapper so everything is reachable from tests.
- **Adding a test**: drop a new `tests/test_<thing>.c` in place. It is globbed,
  built and registered with CTest automatically — no CMake edit required.
- **Tests use Unity**, fetched by `FetchContent` in `tests/CMakeLists.txt` at the
  pinned tag; a clean configure needs network. Every `test_*.c` must define
  `setUp`/`tearDown` (each file is its own executable) and call `UNITY_BEGIN()` /
  `RUN_TEST(...)` / `return UNITY_END()`. Unity is declared `SYSTEM EXCLUDE_FROM_ALL`:
  `SYSTEM` stops its macro expansions tripping `-Werror` and keeps clang-tidy off its
  headers, `EXCLUDE_FROM_ALL` discards its install rules so `make install` ships only
  the executable. Do not remove either keyword — `EXCLUDE_FROM_ALL` is why the CMake
  minimum is 3.28.
- **Warnings, sanitizers and coverage** are carried by the `project_warnings`,
  `project_sanitizers` and `project_coverage` INTERFACE targets in
  `CMakeLists.txt`. Anything that compiles project code must link them (linking
  `MyProject_core` is enough, since it propagates them `PUBLIC`).
- **Do not add compile options to individual targets** — add them to the shared
  INTERFACE targets so every target stays consistent.
- **Document public declarations** in `include/` with Doxygen `@brief`/`@param`/
  `@return` comments; `include/greeting.h` shows the expected style. `make docs`
  is not part of `make qa`, so a missing comment warns rather than failing.
  The Doxyfile is generated from `CMakeLists.txt` — do not add one to the repo.
- The project name is defined once, in the `project()` call. The Makefile reads
  it back from `CMakeCache.txt`; do not hardcode it elsewhere.

## Commands

```sh
make init NAME=Foo   # one-time rename of the template
make all             # build plus docs for the selected config — the default goal
make debug           # configure + build (CONFIG=debug is the default)
make build           # configure + build Release
make test            # run the suite via the ctest preset
make lint            # tidy and cppcheck
make qa              # format-check, lint plus the build and the tests (alias: check)
make pre-commit      # format, then tidy — run before committing
make coverage        # llvm-cov report + HTML (alias: test-cov)
make docs            # Doxygen HTML under build/<config>/docs/html/
make install         # install the executable under PREFIX (default ~/.local)
make uninstall       # remove the files `make install` wrote, per install_manifest.txt
make clean           # remove the selected build dir (clean-all: every build dir)
```

`cbuild` builds the current `CONFIG` without reconfiguring and is the primitive the
other targets compose. `build` is an alias for `release`, so it ignores `CONFIG`.

`CONFIG` selects the preset: `debug`, `release`, `relwithdebinfo`, `coverage`.

## Quality gates are hard gates

`make qa` fails on clang-tidy findings (`--warnings-as-errors=*` on the `tidy`
target), on cppcheck findings (`--error-exitcode=1`), and on sanitizer findings
(`-fno-sanitize-recover=all`). Do not weaken these to get a build through — fix
the finding, or add a narrowly scoped `// NOLINT(check-name)` / cppcheck
`// cppcheck-suppress` comment with a reason.

## Platform

macOS-only by design: `CMakePresets.json` pins `/usr/bin/clang` and
`CMAKE_OSX_SYSROOT`, and tool discovery prefers Xcode's toolchain via `xcrun`
(required — `llvm-profdata` must match the compiler that produced the profiles).
Machine-specific overrides belong in `CMakeUserPresets.json`, which is gitignored.
