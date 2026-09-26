# ==============================================================================
# Developer Makefile
#
# Thin wrapper around CMake Presets.
# All build logic lives in:
#   - CMakeLists.txt
#   - CMakePresets.json
# ==============================================================================

CONFIG ?= debug
BUILD_DIR := build/$(CONFIG)

# Read the project name back from the configured cache, so that the name is
# defined in exactly one place (the project() call in CMakeLists.txt).
# Deliberately lazy (`=`, not `:=`): it must be evaluated after `configure`.
PROJECT = $(shell sed -n 's/^CMAKE_PROJECT_NAME:STATIC=//p' $(BUILD_DIR)/CMakeCache.txt 2>/dev/null)

CMAKE := cmake
CTEST := ctest

DESTDIR ?=
# A user-local default, so `make install` needs no sudo. This is the
# developer wrapper's opinion only: CMAKE_INSTALL_PREFIX in CMakeLists.txt
# keeps CMake's standard /usr/local for packagers calling cmake directly.
# $(HOME), not ~ - Make does not expand a tilde.
PREFIX ?= $(HOME)/.local

# A bare `make` builds and documents the selected config; `make help` still
# lists every target.
.DEFAULT_GOAL := all

.PHONY: \
	help \
	init \
	configure \
	debug \
	release \
	relwithdebinfo \
	build \
	cbuild \
	all \
	run \
	format \
	format-check \
	tidy \
	cppcheck \
	lint \
	test \
	tests \
	coverage \
	test-cov \
	docs \
	qa \
	check \
	pre-commit \
	install \
	uninstall \
	clean \
	clean-all \
	rebuild

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo ""
	@echo "Available targets"
	@echo "================="
	@echo ""
	@echo "Getting started"
	@echo "---------------"
	@echo "  make init NAME=Foo   Rename the template to your project name"
	@echo ""
	@echo "Configuration"
	@echo "-------------"
	@echo "  make configure       Configure the selected preset (CONFIG=debug by default)"
	@echo "  make debug           Configure and build Debug"
	@echo "  make release         Configure and build Release"
	@echo "  make relwithdebinfo  Configure and build RelWithDebInfo"
	@echo ""
	@echo "Building"
	@echo "--------"
	@echo "  make build           Configure and build Release (alias for 'release')"
	@echo "  make cbuild          Build selected configuration (CONFIG=debug by default)"
	@echo "  make all             Build the selected configuration and generate the docs (default)"
	@echo "  make run ARGS='...'  Build and run the executable"
	@echo "  make install         Install the executable (PREFIX defaults to ~/.local)"
	@echo "  make uninstall       Remove the files a previous 'make install' wrote"
	@echo ""
	@echo "Code Quality"
	@echo "------------"
	@echo "  make format          Format source code"
	@echo "  make format-check    Verify formatting without changing files"
	@echo "  make tidy            Run clang-tidy (findings fail the build)"
	@echo "  make cppcheck        Run cppcheck (findings fail the build)"
	@echo "  make lint            Run tidy and cppcheck"
	@echo "  make test            Run unit tests"
	@echo "  make coverage        Run tests and generate a coverage report (alias: test-cov)"
	@echo "  make docs            Generate API docs under build/<config>/docs/html/"
	@echo "  make qa              Run format-check and lint plus the build and the tests (alias: check)"
	@echo "  make pre-commit      Format, then run tidy"
	@echo ""
	@echo "Maintenance"
	@echo "-----------"
	@echo "  make clean           Remove the selected build directory (CONFIG=debug by default)"
	@echo "  make clean-all       Remove all build directories"
	@echo "  make rebuild         Clean and rebuild the selected configuration"
	@echo ""

# ==============================================================================
# Getting started
# ==============================================================================

init:
	@./scripts/init-project.sh $(NAME)

# ==============================================================================
# Configure
# ==============================================================================

configure:
	$(CMAKE) --preset $(CONFIG)

# ==============================================================================
# Build Configurations
# ==============================================================================

debug:
	$(MAKE) --no-print-directory CONFIG=debug configure cbuild

release:
	$(MAKE) --no-print-directory CONFIG=release configure cbuild

relwithdebinfo:
	$(MAKE) --no-print-directory CONFIG=relwithdebinfo configure cbuild

# ==============================================================================
# Build
# ==============================================================================

cbuild:
	$(CMAKE) --build --preset $(CONFIG)

# Alias. Unlike `cbuild`, this ignores CONFIG - `release` pins it - so `make
# build` always produces the shippable artifact.
build: release

# Everything a plain build produces: the binaries plus the generated API docs.
# This is the default goal, so a bare `make` runs it - see .DEFAULT_GOAL above,
# which overrides Make's own rule of taking the first target in the file.
all:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure cbuild
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) docs

run: configure cbuild
	./$(BUILD_DIR)/$(PROJECT) $(ARGS)

install: configure cbuild
	$(CMAKE) --install $(BUILD_DIR) --prefix $(PREFIX)

# CMake generates no uninstall rule, so undo the install from the manifest that
# `cmake --install` leaves behind: one absolute installed path per line. It
# records the paths without DESTDIR, so prepend it here the same way the install
# did. Removing files only - directories may hold files this project never
# installed, so they are left in place.
#
# CMake writes the manifest without a trailing newline, so `read` returns
# non-zero on the last path: `|| [ -n "$$file" ]` keeps that final entry from
# being silently skipped.
uninstall:
	@manifest=$(BUILD_DIR)/install_manifest.txt; \
	if [ ! -f "$$manifest" ]; then \
		echo "No $$manifest - nothing was installed from this build directory."; \
		exit 0; \
	fi; \
	while IFS= read -r file || [ -n "$$file" ]; do \
		[ -n "$$file" ] || continue; \
		echo "-- Uninstalling: $(DESTDIR)$$file"; \
		$(CMAKE) -E rm -f "$(DESTDIR)$$file"; \
	done < "$$manifest"

# ==============================================================================
# Code Quality
# ==============================================================================

format:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure
	$(CMAKE) --build $(BUILD_DIR) --target format

format-check:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure
	$(CMAKE) --build $(BUILD_DIR) --target format-check

tidy:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure
	$(CMAKE) --build $(BUILD_DIR) --target tidy

cppcheck:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure cbuild
	$(CMAKE) --build $(BUILD_DIR) --target cppcheck

# Static analysis only: qa without the build step or the test run.
lint:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) tidy
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) cppcheck

test: configure cbuild
	$(CTEST) --preset $(CONFIG)

# Alias. `tests/` is a real directory, so without a .PHONY target of this name
# `make tests` matches the directory, reports "Nothing to be done" and silently
# runs nothing.
tests: test

coverage:
	$(MAKE) --no-print-directory CONFIG=coverage configure cbuild
	$(CMAKE) --build build/coverage --target coverage

# Alias.
test-cov: coverage

# Deliberately not part of `qa` - documentation gaps warn, they do not block.
docs:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure
	$(CMAKE) --build $(BUILD_DIR) --target docs

qa:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) format-check
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) cbuild
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) tidy
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) cppcheck
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) test

# Alias, matching the GNU convention where `check` runs the full gate.
check: qa

pre-commit:
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) format
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) tidy

# ==============================================================================
# Maintenance
# ==============================================================================

clean:
	$(CMAKE) -E rm -rf $(BUILD_DIR)

clean-all:
	$(CMAKE) -E rm -rf build

rebuild: clean
	$(MAKE) --no-print-directory CONFIG=$(CONFIG) configure cbuild
