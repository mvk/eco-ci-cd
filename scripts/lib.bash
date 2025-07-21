#!/usr/bin/env bash
# shellcheck disable=SC2065
###############################################################################
# Make targets logic in shell
###############################################################################
# TODO: migrate this code into python
###############################################################################

set -o pipefail

SCRIPT_DBG="${SCRIPT_DBG:-0}"
# whether we shall not send data and set specific CI
DEV_MODE="${DEV_MODE:-0}"
# use the default python3.
PY="${PY:-"python3"}"
# where to install current venv directory
VENV_DIR="${VENV_DIR:-"${PWD}/.venv"}"
# whether to recreate the venv
RECREATE="${RECREATE:-0}"
# this option affects die function behavior
LIVE_FOREVER="${LIVE_FOREVER:-"0"}"

function log.msg() {
  local \
    level \
    ts
  local -a msg
  level="${1?cannot continue without level}"
  level="${level^^}"
  shift 1
  msg=("${@}")
  if [[ "${level}" = "DEBUG" && "${SCRIPT_DBG}" -eq 0 ]]; then
    return 0
  fi
  ts="$(date -u || true)"
  echo -e -n "${ts} - ${level} - ${msg[*]}\n"
  return 0
}

function log.info() {
  local level="${FUNCNAME[0]}"
  local -a msg=("${@}")
  log.msg "${level##*.}" "${msg[@]}"
  return $?
}

function log.error() {
  local level="${FUNCNAME[0]}"
  local -a msg=("${@}")
  log.msg "${level##*.}" "${msg[@]}"
  return $?
}

function log.fatal() {
  local level="${FUNCNAME[0]}"
  local -a msg=("${@}")
  log.msg "${level##*.}" "${msg[@]}"
  return $?
}

function log.warn() {
  local op="${FUNCNAME[0]}"
  local -a msg=("${@}")
  log.msg "${op##*.}" "${msg[@]}"
  return $?
}

function log.debug() {
  local level="${FUNCNAME[0]}"
  local -a msg=("${@}")
  log.msg "${level##*.}" "${msg[@]}"
  return $?
}

###################################################################################################
# die prints the message and exits with rc
# if LIVE_FOREVER is non 0, it returns.
###################################################################################################
function die() {
  local rc msg
  rc="${1?cannot without rc}"
  shift 1
  msg="${*}"
  log.fatal "${msg}"
  if [[ "${LIVE_FOREVER}" -ne 0 ]]; then
    return "${rc}"
  fi
  exit "${rc}"
}

###################################################################################################
# prolog prints the name of the caller function and passed arguments
# it should be called by callers as the FIRST command of a function like this: prolog "${@}"
###################################################################################################
function prolog() {
  local \
    func_name
  local -a \
    vars
  vars=("${@}")
  func_name="${FUNCNAME[1]}"
  log.debug "Inside ${func_name}()\n"
  log.debug "The call (debug) was: '${FUNCNAME[1]} ${vars[*]}'\n"
  return 0
}

###################################################################################################
# epilog prints the name of the caller function and how it returned
# it should be called by callers as the LAST command of a function like this: epilog "${@}"
###################################################################################################
function epilog() {
  local \
    name \
    rc
  local -a msg
  name="${FUNCNAME[1]}"
  rc="${1?cannot continue without rc}"
  shift 1
  msg=("Function ${name}()")
  msg+=("${@}")
  msg+=("completed with rc=${rc}")
  log.debug "${msg[@]}"
}

###################################################################################################
# run_cmd runs a command and checks the return code
# it should be called by callers as the LAST command of a function like this: run_cmd "${@}"
###################################################################################################
function run_cmd() {
  local -a \
    cmd
  local \
    expected_rc \
    rc
  prolog "${@}"
  expected_rc="${1?cannot continue without expected_rc}"
  shift 1
  cmd=("${@}")
  test "${#cmd[@]}" -ne 0 || die 1 "The command '${cmd[*]}' cannot be empty"
  log.debug "About to run command: '${cmd[*]}'"
  "${cmd[@]}"
  rc=$?
  test "${rc}" -eq "${expected_rc}" || die "${rc}" "The command returned unexpected rc=${rc}. [EXPECTED: ${expected_rc}]"
  epilog "${rc}"
  return "${rc}"
}

function venv.is_venv() {
  local \
    venv_dir \
    py_exec \
    curr_py \
    venv_py \
    out
  venv_dir="${1?cannot continue without venv_dir}"
  py_exec="${2:-"${PY}"}"
  curr_py="$(command -v "${py_exec}" 2>/dev/null || true)"
  venv_py="$(realpath "${venv_dir}/bin/${py_exec}" || true)"
  out="true"
  if [[ "${venv_py}" != "${curr_py}" ]]; then
    out="false"
  fi
  echo "${out}"
  return 0

}

function source_script() {
  local \
    script_path \
    subdir \
    rc
  local -a \
    paths_to_script
  script_path="${1?cannot continue without script_path}"

  paths_to_script=("$(dirname "${script_path}" || true)")
  paths_to_script=("$(dirname "${paths_to_script[0]}" || true)" "${paths_to_script[@]}")
  paths_to_script=("$(dirname "${paths_to_script[0]}" || true)" "${paths_to_script[@]}")

  # validations: dirs presence + permissions
  for subdir in "${paths_to_script[@]}"; do
    test -d "${subdir}" || die 1 "'${subdir}' folder is missing"
    test -x "${subdir}" || die 1 "'${subdir}' folder is non executable"
  done
  # validations: script permissions
  test -r "${script_path}" || die 1 "Expected script file ${script_path} is not readable."
  # shellcheck disable=SC1090,SC1091
  source "${script_path}"
  rc=$?
  log.debug "sourced ${script_path} with rc=${rc}"
  test "${rc}" -eq 0 || die "${rc}" "Failed on ${script_path} sourcing. Please check your environment."
  return "${rc}"
}

function venv.activate() {
  local \
    venv_dir \
    py_exec \
    subdir \
    expected_rc \
    rc
  prolog "${@}"
  venv_dir="${1?cannot continue without venv_dir}"
  py_exec="${2:-"${PY}"}"
  expected_rc=0
  venv_enabled="$(venv.is_venv "${venv_dir}" "${py_exec}" || true)"
  if [[ "${venv_enabled}" = "true" ]]; then
    log.warn "venv ${venv_dir} is currently active"
    return 0
  fi
  log.info "Activating venv in ${venv_dir}"
  source_script "${venv_dir}/bin/activate"
  rc=$?
  test "${rc}" -eq "${expected_rc}" || die "${rc}" "Activating venv '${venv_dir}' returned rc=${rc} [EXPECTED: ${expected_rc}]"
  epilog "${rc}"
  return "${rc}"
}

function venv.install() {
  local \
    msg \
    item \
    venv_dir \
    host_py \
    venv_py \
    rc
  local -a \
    requirements \
    vars \
    cmd
  prolog "${@}"
  venv_dir="${1?cannot continue without venv_dir}"
  vars+=(venv_dir)
  shift 1
  host_py="${1:-"${PY}"}"
  vars+=(host_py)
  shift 1
  requirements+=("${@}")

  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  if [[ "${#requirements[@]}" -eq 0 ]]; then
    requirements+=("requirements.txt")
  fi
  log.debug "Using requirements: ${requirements[*]}"
  venv_py="${host_py##*/}"
  log.debug "==> Creating venv at ${venv_dir}"
  cmd=("${host_py}" -m venv "${venv_dir}")
  run_cmd 0 "${cmd[@]}"
  rc=$?
  venv.activate "${venv_dir}" "${venv_py}"
  rc=$?
  log.debug "<== Created venv of ${venv_py} in ${venv_dir} and activated it"
  log.debug "==> Upgrading venv pip of ${venv_py}"
  cmd=("${venv_py}" -m pip install --upgrade pip)
  # save old value
  run_cmd 0 "${cmd[@]}"
  rc=$?
  log.debug "<== Upgraded pip using venv python ${venv_py} with rc=${rc}"
  cmd=("${venv_py}" -m pip install)
  for item in "${requirements[@]}"; do
    cmd+=("-r" "${item}")
  done
  log.debug "==> Installing pip packages of venv in ${venv_py}"
  run_cmd 0 "${cmd[@]}"
  rc=$?
  log.debug "<== Installed pip packages of venv from ${requirements[*]} with rc=${rc}"
  log.debug "==> Version info on python interpreter: $("${venv_py}" --version || true)"
  log.info "<== Completed venv creation under ${venv_dir}"
  epilog "${rc}"
  return "${rc}"
}

function venv.lazy_install() {
  local \
    msg \
    item \
    venv_dir \
    recreate \
    var \
    val \
    rc
  local -a \
    vars
  prolog "${@}"
  venv_dir="${1:-"${VENV_DIR}"}"
  vars+=(venv_dir)
  shift 1
  py="${1:-"${PY}"}"
  vars+=(py)
  shift 1
  recreate="${1:-"${RECREATE}"}"
  vars+=(recreate)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  rc=0
  if [[ -d "${venv_dir}" ]]; then
    if [[ "${recreate}" -eq 0 ]]; then
      log.warn "no need to install venv. [REASON: recreate=${recreate}]"
      return "${rc}"
    fi
  fi
  if [[ "${recreate}" -gt 0 ]]; then
    rm -fr "${venv_dir}"
    log.info "Deleted venv: ${venv_dir}. [REASON: recreate=${recreate}]"
  fi
  venv.install "${venv_dir}" "${py}"
  rc=$?
  return "${rc}"
}

function py.reqs_install() {
  local \
    requirement \
    rc
  prolog "${@}"
  requirement="${1?cannot continue without requirement}"
  curr_cmd=(pip3 install -r "${requirement}")
  log.info "Installing python requirements from requirements yaml file: ${requirement}"
  run_cmd 0 "${curr_cmd[@]}"
  rc=$?
  epilog "${rc}" "Installed python requirements from: ${requirement}"
  return "${rc}"
}


if [[ "$0" = "${BASH_SOURCE:-""}" ]]; then
  log.error "This script is meant to be sourced. Please do not run it directly."
  exit 1
fi