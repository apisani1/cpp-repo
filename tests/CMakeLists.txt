# ==============================================================================
# Tests
#
# Every tests/test_*.c file becomes its own executable and its own CTest test.
# Adding a test means adding a file here - no CMake changes required.
# ==============================================================================

# ------------------------------------------------------------------------------
# Unity
#
# Declared here rather than at the top level so that a consumer building the
# library with BUILD_TESTING=OFF never pays for the download.
#
# SYSTEM is load-bearing, not cosmetic. It marks Unity's headers as system
# includes, which stops -Wconversion warnings raised by TEST_ASSERT_* macro
# expansions from tripping -Werror in our own translation units, and keeps
# clang-tidy off Unity's headers - they live under _deps/unity-src/**/src/,
# which otherwise matches HeaderFilterRegex in .clang-tidy.
#
# EXCLUDE_FROM_ALL keeps Unity out of the ALL target and, more importantly,
# discards its install rules. Unity installs its library, headers and CMake
# package files unconditionally, so without this `make install` would drop a
# test framework into the prefix alongside the executable.
#
# SYSTEM needs CMake 3.25 and EXCLUDE_FROM_ALL needs 3.28; the project minimum
# is 3.28 for exactly this reason.
# ------------------------------------------------------------------------------

include(FetchContent)

FetchContent_Declare(unity
    GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
    GIT_TAG        v2.7.0
    GIT_SHALLOW    TRUE
    SYSTEM
    EXCLUDE_FROM_ALL
)

FetchContent_MakeAvailable(unity)

# ------------------------------------------------------------------------------
# Test executables
# ------------------------------------------------------------------------------

file(GLOB test_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/test_*.c")

foreach(test_source IN LISTS test_sources)

    cmake_path(GET test_source STEM test_name)

    add_executable(${test_name} ${test_source})

    target_include_directories(${test_name}
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}
    )

    # Links the shared warning, sanitizer and coverage settings through the
    # core library, so test code is held to the same standard as src/.
    target_link_libraries(${test_name}
        PRIVATE
            ${PROJECT_NAME}_core
            unity::framework
    )

    add_test(
        NAME ${test_name}
        COMMAND ${test_name}
    )

    set_tests_properties(${test_name} PROPERTIES
        ENVIRONMENT "UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1;ASAN_OPTIONS=abort_on_error=1"
    )

endforeach()
