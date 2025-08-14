#!/usr/bin/env bash

DEV_MODE="${DEV_MODE:-"0"}"
BUILD_MODE="${BUILD_MODE:-"0"}"

if ! command -v pip-compile 2>/dev/null >/dev/null; then
  echo "FATAL: pip-compile not on PATH. please install it"
  exit 1
fi

SRC_LIST=(requirements.in)
if [[ "${DEV_MODE}" -gt 0 ]]; then
  SRC_LIST+=(requirements-dev.in)
fi
if [[ "${BUILD_MODE}" -gt 0 ]]; then
  SRC_LIST+=(requirements-build.in)
fi

dst_file="requirements.txt"
pip-compile --color "${SRC_LIST[@]}" -o "${dst_file}"
echo "destination file: ${dst_file}"
