#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
if [[ -n "${VENV_DIR}" && -f "${VENV_DIR}/bin/activate" ]]; then
    source "${VENV_DIR}/bin/activate"
fi
if [[ "$#" -gt 0 && "${1}" = "-c" ]]; then
    exec bash -c "${2}"
else
    exec "${@}"
fi
