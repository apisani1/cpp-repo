cmake_minimum_required(VERSION 3.28)

# ==============================================================================
# Project
# ==============================================================================

project(
    MyProject
    VERSION 1.0.0
    DESCRIPTION "My C++ Project"
    LANGUAGES C CXX
)

# ==============================================================================
# Options
# ==============================================================================

option(ENABLE_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)
option(ENABLE_SANITIZERS "Enable AddressSanitizer and UBSan in Debug builds" ON)
option(ENABLE_COVERAGE "Instrument for source-based coverage (use the coverage preset)" OFF)

# ==============================================================================
# Language
# ==============================================================================

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Generate compile_commands.json (consumed by clangd, clang-tidy and cppcheck)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ==============================================================================
# Shared Build Settings
#
# These INTERFACE targets carry the project's compiler discipline. Every target
# that compiles project code links them, so warnings, sanitizers and coverage
# instrumentation apply uniformly to the library, the executable and the tests.
# ==============================================================================

add_library(project_warnings INTERFACE)
add_library(project_sanitizers INTERFACE)
add_library(project_coverage INTERFACE)

set(project_warning_options

    # General
    -Wall
    -Wextra
    -Wpedantic

    # Type safety
    -Wconversion
    -Wsign-conversion
    -Wshadow
    -Wundef

    # Floating point
    -Wdouble-promotion

    # printf / scanf
    -Wformat=2

    # Const correctness
    -Wcast-qual
    -Wwrite-strings

    # Function declarations
    $<$<COMPILE_LANGUAGE:C>:-Wstrict-prototypes>
    $<$<COMPILE_LANGUAGE:C>:-Wmissing-prototypes>

    # C++ class safety
    $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor>
    $<$<COMPILE_LANGUAGE:CXX>:-Woverloaded-virtual>

    # switch statements
    -Wimplicit-fallthrough

    $<$<BOOL:${ENABLE_WARNINGS_AS_ERRORS}>:-Werror>

)

# Select each source's compiler independently, including in mixed toolchains.
foreach(language IN ITEMS C CXX)
    target_compile_options(project_warnings INTERFACE
        "$<$<COMPILE_LANG_AND_ID:${language},Clang,AppleClang,GNU>:${project_warning_options}>"
    )
endforeach()

# ==============================================================================
# Sanitizers (Debug only)
# ==============================================================================

if(ENABLE_SANITIZERS
   AND CMAKE_BUILD_TYPE STREQUAL "Debug"
   AND CMAKE_C_COMPILER_ID MATCHES "Clang|AppleClang|GNU")

    target_compile_options(project_sanitizers INTERFACE
        -fsanitize=address,undefined
        # Without this UBSan reports and continues, so an undefined-behaviour
        # finding does not fail the test that triggered it.
        -fno-sanitize-recover=all
        -fno-omit-frame-pointer
    )

    target_link_options(project_sanitizers INTERFACE
        -fsanitize=address,undefined
    )

endif()

# ==============================================================================
# Coverage
# ==============================================================================

if(ENABLE_COVERAGE AND CMAKE_C_COMPILER_ID MATCHES "Clang|AppleClang")

    target_compile_options(project_coverage INTERFACE
        -fprofile-instr-generate
        -fcoverage-mapping
    )

    target_link_options(project_coverage INTERFACE
        -fprofile-instr-generate
        -fcoverage-mapping
    )

endif()

# ==============================================================================
# Library
#
# All application logic lives here so that both the executable and the tests
# can link against it. Add new sources to this target.
# ==============================================================================

add_library(${PROJECT_NAME}_core STATIC
    src/greeting.c
)

target_include_directories(${PROJECT_NAME}_core
    PUBLIC
        include
)

target_link_libraries(${PROJECT_NAME}_core
    PUBLIC
        project_warnings
        project_sanitizers
        project_coverage
)

# ==============================================================================
# Executable
# ==============================================================================

add_executable(${PROJECT_NAME}
    src/main.cpp
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
        ${PROJECT_NAME}_core
)

# ==============================================================================
# Install
# ==============================================================================

include(GNUInstallDirs)

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# ==============================================================================
# Editor Integration
#
# clangd finds its compilation database by walking up from each source file, so
# link the Debug database into the source root. Without this, clangd falls back
# to a default command line with no -I flags and reports "'greeting.h' file not
# found" for code that compiles cleanly.
#
# Debug only: otherwise `make qa CONFIG=release` would silently repoint the
# editor at release flags, and the coverage preset at instrumented ones.
# ==============================================================================

if(PROJECT_IS_TOP_LEVEL AND CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT ENABLE_COVERAGE)

    file(CREATE_LINK
        "${CMAKE_BINARY_DIR}/compile_commands.json"
        "${CMAKE_SOURCE_DIR}/compile_commands.json"
        SYMBOLIC
    )

endif()

# ==============================================================================
# Testing
# ==============================================================================

if(PROJECT_IS_TOP_LEVEL)

    include(CTest)

    if(BUILD_TESTING)
        add_subdirectory(tests)
    endif()

endif()

# ==============================================================================
# Tool Discovery
#
# On macOS the Xcode toolchain is preferred, because the compiler is Xcode's
# clang and mixing toolchains (notably llvm-profdata against Apple clang
# profiles) does not work.
# ==============================================================================

function(find_development_tool output_variable tool_name)

    # Each tool gets its own cache variable. Sharing one name across calls made
    # find_program() a no-op after the first hit, so every tool resolved to the
    # first tool found.
    if(DEFINED CACHE{${output_variable}})
        return()
    endif()

    if(APPLE)
        find_program(XCRUN_EXE xcrun)

        if(XCRUN_EXE)
            execute_process(
                COMMAND ${XCRUN_EXE} --find ${tool_name}
                OUTPUT_VARIABLE found_path
                OUTPUT_STRIP_TRAILING_WHITESPACE
                RESULT_VARIABLE xcrun_result
                ERROR_QUIET
            )

            if(xcrun_result EQUAL 0 AND EXISTS "${found_path}")
                set(${output_variable} "${found_path}"
                    CACHE FILEPATH "Path to ${tool_name}")
                return()
            endif()
        endif()
    endif()

    find_program(${output_variable} ${tool_name} DOC "Path to ${tool_name}")

endfunction()

find_development_tool(CLANG_FORMAT_EXE clang-format)
find_development_tool(CLANG_TIDY_EXE clang-tidy)
find_development_tool(CPPCHECK_EXE cppcheck)
find_development_tool(LLVM_PROFDATA_EXE llvm-profdata)
find_development_tool(LLVM_COV_EXE llvm-cov)

foreach(tool_variable IN ITEMS
        CLANG_FORMAT_EXE CLANG_TIDY_EXE CPPCHECK_EXE LLVM_PROFDATA_EXE LLVM_COV_EXE)
    if(${tool_variable})
        message(STATUS "Found ${tool_variable}: ${${tool_variable}}")
    else()
        message(STATUS "Missing ${tool_variable} (the matching make target will fail)")
    endif()
endforeach()

# Discover both languages for tooling; production targets list sources explicitly.
set(PROJECT_SOURCES "")
set(PROJECT_FORMAT_SOURCES "")
foreach(source_dir IN ITEMS src include tests)
    foreach(extension IN ITEMS c cc cpp cxx)
        file(GLOB_RECURSE sources CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/${source_dir}/*.${extension}")
        list(APPEND PROJECT_SOURCES ${sources})
        list(APPEND PROJECT_FORMAT_SOURCES ${sources})
    endforeach()
    foreach(extension IN ITEMS h hh hpp hxx inl tpp)
        file(GLOB_RECURSE headers CONFIGURE_DEPENDS
            "${CMAKE_CURRENT_SOURCE_DIR}/${source_dir}/*.${extension}")
        list(APPEND PROJECT_FORMAT_SOURCES ${headers})
    endforeach()
endforeach()

# ==============================================================================
# format
# ==============================================================================

if(CLANG_FORMAT_EXE)

    add_custom_target(format

        COMMAND
            ${CLANG_FORMAT_EXE}
            -i
            ${PROJECT_FORMAT_SOURCES}

        WORKING_DIRECTORY
            ${CMAKE_SOURCE_DIR}

        COMMENT
            "Formatting project"

    )

    add_custom_target(format-check

        COMMAND
            ${CLANG_FORMAT_EXE}
            --dry-run
            --Werror
            ${PROJECT_FORMAT_SOURCES}

        WORKING_DIRECTORY
            ${CMAKE_SOURCE_DIR}

        COMMENT
            "Checking project formatting"

    )

else()

    add_custom_target(format
        COMMAND ${CMAKE_COMMAND} -E echo "clang-format was not found. Install it and reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

    add_custom_target(format-check
        COMMAND ${CMAKE_COMMAND} -E echo "clang-format was not found. Install it and reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

endif()

# ==============================================================================
# tidy
#
# Warnings are promoted to errors here rather than in .clang-tidy, so that the
# editor (clangd) still shows them as warnings while `make tidy` and CI fail.
# ==============================================================================

if(CLANG_TIDY_EXE)

    add_custom_target(tidy

        COMMAND
            ${CLANG_TIDY_EXE}
            --quiet
            --warnings-as-errors=*
            -p
            ${CMAKE_BINARY_DIR}
            ${PROJECT_SOURCES}

        WORKING_DIRECTORY
            ${CMAKE_SOURCE_DIR}

        COMMENT
            "Running clang-tidy"

    )

else()

    add_custom_target(tidy
        COMMAND ${CMAKE_COMMAND} -E echo "clang-tidy was not found. Install it and reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

endif()

# ==============================================================================
# cppcheck
#
# --error-exitcode is what makes findings fail the build; without it cppcheck
# always exits 0 and the quality gate is decorative.
# ==============================================================================

if(CPPCHECK_EXE)

    add_custom_target(cppcheck

        COMMAND
            ${CPPCHECK_EXE}
            --project=${CMAKE_BINARY_DIR}/compile_commands.json
            --enable=warning,performance,portability,style
            --error-exitcode=1
            --inline-suppr
            --check-level=exhaustive
            --suppress=missingIncludeSystem
            --suppress=unusedFunction
            --suppress=checkersReport
            -i${CMAKE_BINARY_DIR}

        WORKING_DIRECTORY
            ${CMAKE_SOURCE_DIR}

        COMMENT
            "Running cppcheck"

    )

else()

    add_custom_target(cppcheck
        COMMAND ${CMAKE_COMMAND} -E echo "cppcheck was not found. Install it and reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

endif()

# ==============================================================================
# coverage
# ==============================================================================

if(ENABLE_COVERAGE AND LLVM_PROFDATA_EXE AND LLVM_COV_EXE)

    add_custom_target(coverage

        COMMAND
            ${CMAKE_COMMAND}
            -D BINARY_DIR=${CMAKE_BINARY_DIR}
            -D SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -D CTEST_EXE=${CMAKE_CTEST_COMMAND}
            -D LLVM_PROFDATA_EXE=${LLVM_PROFDATA_EXE}
            -D LLVM_COV_EXE=${LLVM_COV_EXE}
            -P ${CMAKE_SOURCE_DIR}/cmake/RunCoverage.cmake

        WORKING_DIRECTORY
            ${CMAKE_SOURCE_DIR}

        COMMENT
            "Running tests and generating a coverage report"

        USES_TERMINAL

    )

elseif(NOT ENABLE_COVERAGE)

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -E echo "Coverage is disabled. Use: make coverage (CONFIG=coverage)."
        COMMAND ${CMAKE_COMMAND} -E false
    )

else()

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -E echo "llvm-profdata or llvm-cov was not found. Install them and reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

endif()

# ==============================================================================
# docs
#
# The Doxyfile is generated from these variables rather than checked in, so the
# project name keeps coming from the single project() call and init-project.sh
# has no extra file to rewrite.
#
# find_package(Doxygen) is used instead of find_development_tool(): that helper
# prefers Xcode's toolchain via xcrun, which is right for llvm-profdata and
# wrong for a Homebrew tool.
# ==============================================================================

find_package(Doxygen)

if(DOXYGEN_FOUND)

    set(DOXYGEN_PROJECT_NAME ${PROJECT_NAME})
    set(DOXYGEN_PROJECT_NUMBER ${PROJECT_VERSION})
    set(DOXYGEN_PROJECT_BRIEF ${PROJECT_DESCRIPTION})
    set(DOXYGEN_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/docs)

    # Preserve class-oriented documentation for C++ and mixed-language projects.
    set(DOXYGEN_OPTIMIZE_OUTPUT_FOR_C NO)

    set(DOXYGEN_GENERATE_HTML YES)
    set(DOXYGEN_GENERATE_LATEX NO)

    # Document what is commented, not everything, but say so when a public
    # declaration has no comment.
    set(DOXYGEN_EXTRACT_ALL NO)
    set(DOXYGEN_WARN_IF_UNDOCUMENTED YES)
    set(DOXYGEN_QUIET YES)

    # Advisory by design: `docs` is not part of `make qa`, so a missing comment
    # warns rather than failing the build. Set DOXYGEN_WARN_AS_ERROR to
    # FAIL_ON_WARNINGS to make it a hard gate.

    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE ${CMAKE_SOURCE_DIR}/README.md)

    # Inputs are positional: doxygen_add_docs() warns and ignores DOXYGEN_INPUT.
    # tests/ is deliberately excluded.
    doxygen_add_docs(docs

        ${CMAKE_SOURCE_DIR}/include
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/README.md

        COMMENT
            "Generating API documentation"

    )

else()

    add_custom_target(docs
        # No parentheses in this message: CMake does not shell-quote them and
        # /bin/sh fails with a syntax error before the hint is ever printed.
        COMMAND ${CMAKE_COMMAND} -E echo "doxygen was not found. Run brew install doxygen, then reconfigure."
        COMMAND ${CMAKE_COMMAND} -E false
    )

endif()
