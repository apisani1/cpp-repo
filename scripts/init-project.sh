#!/usr/bin/env bash
#
# Rename the template from MyProject to a project name of your choosing.
#
# Usage:
#   make init NAME=Widget
#   ./scripts/init-project.sh Widget [--force]
#
# Idempotent: refuses to run once the template has already been renamed,
# unless --force is passed.

set -euo pipefail

readonly TEMPLATE_NAME="MyProject"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

force=0
new_name=""

for argument in "$@"; do
    case "${argument}" in
        --force)
            force=1
            ;;
        -*)
            printf 'Unknown option: %s\n' "${argument}" >&2
            exit 2
            ;;
        *)
            new_name="${argument}"
            ;;
    esac
done

if [[ -z "${new_name}" ]]; then
    printf 'Usage: make init NAME=YourProject\n' >&2
    exit 2
fi

# CMake target names must be usable as identifiers; keep it conservative.
if [[ ! "${new_name}" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    printf 'Invalid name %q: use a letter followed by letters, digits or underscores.\n' \
        "${new_name}" >&2
    exit 2
fi

if [[ "${new_name}" == "${TEMPLATE_NAME}" ]]; then
    printf 'That is already the template name; pick a different one.\n' >&2
    exit 2
fi

if ! grep -q "${TEMPLATE_NAME}" "${repo_root}/CMakeLists.txt" && [[ "${force}" -eq 0 ]]; then
    printf 'CMakeLists.txt no longer contains %s; this project looks renamed already.\n' \
        "${TEMPLATE_NAME}" >&2
    printf 'Re-run with --force to rename anyway.\n' >&2
    exit 1
fi

files=(
    "CMakeLists.txt"
    "README.md"
    "CLAUDE.md"
    ".vscode/tasks.json"
    ".vscode/launch.json"
)

for file in "${files[@]}"; do
    path="${repo_root}/${file}"

    if [[ ! -f "${path}" ]]; then
        continue
    fi

    if grep -q "${TEMPLATE_NAME}" "${path}"; then
        # BSD and GNU sed disagree on -i; write to a temp file instead.
        temporary="$(mktemp)"
        sed "s/${TEMPLATE_NAME}/${new_name}/g" "${path}" > "${temporary}"
        mv "${temporary}" "${path}"
        printf 'updated %s\n' "${file}"
    fi
done

printf '\nRenamed %s to %s.\n' "${TEMPLATE_NAME}" "${new_name}"
printf 'Existing build directories still reference the old name; run:\n\n'
printf '    make clean-all && make qa\n\n'
