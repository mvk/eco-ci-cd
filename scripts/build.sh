#!/usr/bin/env bash
SCRIPT_DEBUG="${SCRIPT_DEBUG:-0}"
extra_args=("${@}")
multistage="${multistage:-0}"
registry="${registry:-"quay.io/makovgan"}"
hash="${hash:-"$(git rev-parse HEAD || true)"}"
image="${image:-"$(git rev-parse --show-toplevel || true)"}"
image="${image##*/}"
containerfile="${containerfile:-"Containerfile"}"
if [[ "${multistage}" -gt 0 ]]; then
  image="${image}-mb"
  containerfile="${containerfile}.multistage"
fi
declare -a tags=("${hash}")
if [[ -n "${image_tag}" ]]; then
  tags+=("${image_tag}")
else
  tags+=("latest")
fi
tag="$(git tag --points-at=HEAD 2>/dev/null || true)"
if [[ -n "${tag}" ]]; then
  if [[ ! " ${tags[*]} " =~ \ ${tag}\  ]]; then
    tags+=("${tag}")
    test "${SCRIPT_DEBUG}" -gt 0 && echo "registered '${tag}' to the tags list"
  fi
fi
repository="${registry}/${image}"
# if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
echo "##################################################################################"
echo "repository: '${repository}'"
echo "containerfile: '${containerfile}'"
echo "tags: ${tags[*]}"
echo "##################################################################################"
# fi
source podman.env
declare -a curr_cmd
curr_cmd=(podman --log-level debug build "${extra_args[@]}" --no-cache)
for tag in "${tags[@]}"; do
  curr_cmd+=("--tag" "${repository}:${tag}")
done
if ! [[ -r "${containerfile}" ]]; then
  echo "FATAL: containerfile='${containerfile}' cannot be read"
  exit 1
fi
curr_cmd+=(-f "${containerfile}" .)
test "${SCRIPT_DEBUG}" -gt 0 && echo "Running command: '${curr_cmd[*]}'"
time "${curr_cmd[@]}"
RC=$?
test "${SCRIPT_DEBUG}" -gt 0 && echo "Command: '${curr_cmd[*]}' completed with RC=${RC}"
test "${RC}" -eq 0 || exit "${RC}"
for tag in "${hash}" "latest"; do
  curr_cmd=(podman push "${repository}:${tag}")
  test "${SCRIPT_DEBUG}" -gt 0 && echo "Running command: '${curr_cmd[*]}'"
  time "${curr_cmd[@]}"
  RC=$?
  test "${SCRIPT_DEBUG}" -gt 0 && echo "Command: '${curr_cmd[*]}' completed with RC=${RC}"
  test "${RC}" -ne 0 && break
done
exit "${RC}"
