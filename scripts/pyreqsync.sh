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

for src_file in "${SRC_LIST[@]}"; do
  dst_file="${src_file%.*}.txt"
  # echo "dst_file: '${dst_file}'"
  pip-compile --color "${src_file}" -o "${dst_file}" &&
    echo "generated: ${dst_file}"
done
