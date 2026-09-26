# CLAUDE.md — MyProject

C++23 / C23 project built with CMake presets, Ninja, CTest, clang-format, clang-tidy and cppcheck.

@./notes

## Layout

| Path        | Purpose                                                  |
| ----------- | -------------------------------------------------------- |
| `include/`  | Public headers for the core library                      |
| `src/`      | Library sources, plus `main.cpp` (a thin wrapper only)   |
| `tests/`    | One `test_*.c` / `test_*.cpp` per test executable (Unity) |
| `cmake/`    | CMake helper scripts (`RunCoverage.cmake`)               |
| `scripts/`  | `init-project.sh` — one-time template rename             |

## Conventions

- **All logic goes in the core library** (`MyProject_core`), not in `src/main.cpp`.
  `main.cpp` stays a thin wrapper so everything is reachable from tests.
- **Adding a test**: drop a new `tests/test_<thing>.cpp` (or `.c`, `.cc`, `.cxx`)
  in place. It is globbed, built and registered with CTest automatically — no
  CMake edit required.
- **Tests use Unity**, fetched by `FetchContent` in `tests/CMakeLists.txt` at the
  pinned tag; a clean configure needs network. Every test source must define
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

## Mixed C and C++

Both languages are first-class: `project(... LANGUAGES C CXX)`, with C23 and
C++23 and extensions off for both. `src/greeting.c` is C, `src/main.cpp` is C++,
and both a C and a C++ test exercise the same header.

- **Public headers shared with C need `extern "C"` guards** — the
  `#ifdef __cplusplus` / `extern "C" {` pattern in `include/greeting.h`. Without
  them a C++ translation unit mangles the names and the link fails. A header
  that is C++-only needs no guard and can use `.hpp`.
- **Production sources are listed explicitly** in the `add_library`/`add_executable`
  calls, not globbed. Add new `.c`, `.cc`, `.cpp` or `.cxx` files to the core
  target by hand. Only the test executables and the tooling file lists glob.
- **The core library may mix both languages.** CMake picks the C++ linker for
  anything that links a library containing C++ objects, so a pure-C test
  executable still links correctly once `MyProject_core` gains a `.cpp`. Do not
  set `LINKER_LANGUAGE` by hand to work around this.
- **Language-specific warnings use `$<COMPILE_LANGUAGE:...>` genexes** on
  `project_warnings` — `-Wstrict-prototypes` and `-Wmissing-prototypes` are
  C-only, `-Wnon-virtual-dtor` and `-Woverloaded-virtual` are C++-only. Add new
  per-language flags the same way rather than creating another INTERFACE target.
  Common warnings use `COMPILE_LANG_AND_ID` to check each language's compiler
  independently.
- **Test file stems must be unique across extensions.** The stem becomes the
  target and CTest name, so `test_greeting.c` and `test_greeting.cpp` collide and
  fail at configure time. The C++ counterpart here is `test_greeting_cpp.cpp`.
- **In a C++ test, include `unity.h` before defining `setUp`/`tearDown`, and
  leave them at global scope.** Unity declares them inside its own `extern "C"`
  block, which is what gives the definitions C linkage; defining them first, or
  inside a namespace, fails to compile with "different language linkage". Test
  case functions themselves may live in an anonymous namespace.
- **A C++-only clang-tidy check will also fire on `extern "C"` headers**, because
  those headers get analysed as part of every C++ translation unit that includes
  them. This is why `modernize-use-trailing-return-type` cannot be enabled: it
  would demand C++ syntax in headers that must stay valid C.

Tooling extension coverage, all set in `CMakeLists.txt`:

| Tool                   | Extensions                                           |
| ---------------------- | ---------------------------------------------------- |
| clang-tidy, cppcheck   | `.c` `.cc` `.cpp` `.cxx`                             |
| clang-format           | the above plus `.h` `.hh` `.hpp` `.hxx` `.inl` `.tpp` |

`.clang-format` uses `Language: Cpp`, which is clang-format's single mode for
both C and C++; `AccessModifierOffset: -4` keeps `public:` flush with `class`
under the project's 4-space indent.

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

macOS-only by design: `CMakePresets.json` pins `/usr/bin/clang`, `/usr/bin/clang++` and
`CMAKE_OSX_SYSROOT`, and tool discovery prefers Xcode's toolchain via `xcrun`
(required — `llvm-profdata` must match the compiler that produced the profiles).
Machine-specific overrides belong in `CMakeUserPresets.json`, which is gitignored.
