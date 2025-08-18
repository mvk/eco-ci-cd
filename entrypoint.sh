#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail
VENV_DIR="${VENV_DIR:-""}"
test -f "${VENV_DIR}/bin/activate" && source "${VENV_DIR}/bin/activate"
if [[ "$#" -gt 0 && "${1}" = "-c" ]]; then
    exec bash -c "${2}"
else
    exec "${@}"
fi