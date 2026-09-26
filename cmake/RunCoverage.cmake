# ==============================================================================
# Coverage driver
#
# Invoked in script mode by the `coverage` target. Runs the test suite with
# per-process profile output, merges the raw profiles, and produces both a
# terminal summary and an HTML report.
#
# Expects: BINARY_DIR, SOURCE_DIR, CTEST_EXE, LLVM_PROFDATA_EXE, LLVM_COV_EXE
# ==============================================================================

set(coverage_dir "${BINARY_DIR}/coverage-report")

file(REMOVE_RECURSE "${coverage_dir}")
file(MAKE_DIRECTORY "${coverage_dir}")

# ------------------------------------------------------------------------------
# Run the test suite
# ------------------------------------------------------------------------------

execute_process(
    COMMAND ${CMAKE_COMMAND} -E env
            "LLVM_PROFILE_FILE=${coverage_dir}/%p.profraw"
            ${CTEST_EXE} --test-dir "${BINARY_DIR}" --output-on-failure
    RESULT_VARIABLE ctest_result
)

if(NOT ctest_result EQUAL 0)
    message(FATAL_ERROR "Tests failed; no coverage report generated.")
endif()

# ------------------------------------------------------------------------------
# Merge raw profiles
# ------------------------------------------------------------------------------

file(GLOB raw_profiles "${coverage_dir}/*.profraw")

if(NOT raw_profiles)
    message(FATAL_ERROR "No .profraw files were produced. Is ENABLE_COVERAGE on?")
endif()

set(merged_profile "${coverage_dir}/merged.profdata")

execute_process(
    COMMAND ${LLVM_PROFDATA_EXE} merge -sparse -o "${merged_profile}" ${raw_profiles}
    RESULT_VARIABLE profdata_result
)

if(NOT profdata_result EQUAL 0)
    message(FATAL_ERROR "llvm-profdata merge failed.")
endif()

# ------------------------------------------------------------------------------
# Collect the instrumented test binaries
# ------------------------------------------------------------------------------

file(GLOB test_binaries "${BINARY_DIR}/tests/test_*")

list(FILTER test_binaries EXCLUDE REGEX "\\.(dSYM|profraw|profdata)$")

if(NOT test_binaries)
    message(FATAL_ERROR "No test binaries found under ${BINARY_DIR}/tests.")
endif()

list(POP_FRONT test_binaries primary_binary)

set(object_arguments "")

foreach(binary IN LISTS test_binaries)
    list(APPEND object_arguments -object "${binary}")
endforeach()

# ------------------------------------------------------------------------------
# Report
# ------------------------------------------------------------------------------

execute_process(
    COMMAND ${LLVM_COV_EXE} report
            "${primary_binary}" ${object_arguments}
            -instr-profile "${merged_profile}"
            "${SOURCE_DIR}/src" "${SOURCE_DIR}/include"
    RESULT_VARIABLE report_result
)

if(NOT report_result EQUAL 0)
    message(FATAL_ERROR "llvm-cov report failed.")
endif()

execute_process(
    COMMAND ${LLVM_COV_EXE} show
            "${primary_binary}" ${object_arguments}
            -instr-profile "${merged_profile}"
            -format html
            -output-dir "${coverage_dir}/html"
            "${SOURCE_DIR}/src" "${SOURCE_DIR}/include"
    RESULT_VARIABLE show_result
)

if(NOT show_result EQUAL 0)
    message(FATAL_ERROR "llvm-cov show failed.")
endif()

message(STATUS "HTML coverage report: ${coverage_dir}/html/index.html")
