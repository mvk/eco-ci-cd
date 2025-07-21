#!/usr/bin/env bash
# shellcheck disable=SC2065
###############################################################################
# Make targets logic in shell
###############################################################################
# TODO: migrate this code into python
set -o pipefail
SCRIPT_DBG="${SCRIPT_DBG:-0}"
# whether we shall not send data and set specific CI
DEV_MODE="${DEV_MODE:-0}"
# do not recreate by default
RECREATE="${RECREATE:-0}"
# use the default python3.
PY="${PY:-"python3"}"
# where to install current venv directory
VENV_DIR="${VENV_DIR:-"${PWD}/.venv"}"
# this option affects die function behavior
LIVE_FOREVER="${LIVE_FOREVER:-"0"}"

###############################################################################
REPO_ROOT="$(git rev-parse --show-toplevel || true)"
declare -a LIB_SCRIPTS=()
mapfile -t LIB_SCRIPTS < <(find "${REPO_ROOT}/scripts" -name "*.bash" -type f || true)
for lib_script in "${LIB_SCRIPTS[@]}"; do
  if [[ ! -r "${lib_script}" ]]; then
    echo "ERROR: ${lib_script} is not readable"
    exit 1
  fi
  # shellcheck disable=SC1090,SC1091
  source "${lib_script}"
done
###############################################################################
# ansible vars/ directory
VARS_DIR="${VARS_DIR:-"${PWD}/vars"}"
# jinja data file path
OUT_DIR="${OUT_DIR:-"${PWD}/output"}"
# jinja templates directory
TPL_DIR="${TPL_DIR:-"${PWD}/templates"}"
# jinja intermediate data file
DATA_FILE="${DATA_FILE:-"${OUT_DIR}/data.yml"}"
# ansible playbook file
PLAYBOOK="${PLAYBOOK:-"test_report_send.yml"}"
# extra data generator script
GENERATOR="${GENERATOR:-"tools/gen_playbook_extra_vars.py"}"
# extra data file template
TPL_FILE="${TPL_FILE:-"${TPL_DIR}/${PLAYBOOK##*/}.j2"}"
# extra vars for the playbook
EXTRA_VARS="${EXTRA_VARS:-"${VARS_DIR}/${PLAYBOOK##*/}"}"
ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH:-"${PWD}/collections"}"
CACHE_PATH="${CACHE_PATH:-"${PWD}/.ansible"}"
CI_TYPE="${CI_TYPE:-"dci"}"
COLLECTION_ROOT="${COLLECTION_ROOT:-""}"
COLLECTIONS_REQS_LOCAL="${COLLECTIONS_REQS_LOCAL:-"requirements.local.yml"}"
COLLECTION_REQ_FILES_TXT="${COLLECTION_REQ_FILES_TXT:-"requirements.yml"}"
FIXTURES_ROOT="${FIXTURES_ROOT:-"fixtures"}"
TEST_DATA_DIR="${TEST_DATA_DIR:-"${FIXTURES_ROOT}/${CI_TYPE}"}"
REQ_COLLECTIONS_ATTR="${REQ_COLLECTIONS_ATTR:-"collections"}"

###############################################################################
# Set up extra parameters
###############################################################################
if ! declare -p EXTRA_PARAMS 2>/dev/null | grep -q '^declare -a'; then
  # declare it if it isn't defined yet
  declare -a EXTRA_PARAMS
fi
if [[ "${#EXTRA_PARAMS[@]}" -eq 0 ]]; then
  # at least set it to this:
  EXTRA_PARAMS+=("-vv")
fi

declare -a SUPPORTED_ACTIONS
SUPPORTED_ACTIONS=(
  bootstrap
  # buildpkg
  check-requirements
  gendata
  render
  reset-collections-reqs
  run-playbook
  test
)

function help() {
  local \
    item \
    action
  action="${1}"
  echo -e "ERROR: Unsupported action: '${action}'"
  echo -e "\tSupported actions:"
  for item in "${SUPPORTED_ACTIONS[@]}"; do
    echo -e "\t'${item}'"
  done
  echo -e "\t=>\tPlease re-run using a supported action"
}

function install_collection_from_yml() {
  local \
    requirement \
    collections_path \
    rc
  local -a \
    curr_cmd
  prolog "${@}"
  requirement="${1?cannot continue without requirement}"
  collections_path="${2:-"${ANSIBLE_COLLECTIONS_PATH}"}"
  # take the 1st item if it has multiple items separated by :
  collections_path="${collections_path%%:*}"
  curr_cmd=(ansible-galaxy collection install --force -r "${requirement}" -p "${collections_path}")
  run_cmd 0 "${curr_cmd[@]}"
  rc=$?
  epilog "${rc}" "Collection installed from: '${requirement}'"
  return "${rc}"
}

function collections_install() {
  local \
    collections_path \
    var \
    val \
    item \
    sub_dir \
    idx \
    total
  local -a \
    vars \
    requirements \
    cmd
  prolog "${@}"
  collections_path="${1?cannot continue without collections_path}"
  vars+=(collections_path)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  requirements=("${@}")
  total="${#requirements[@]}"
  if [[ "${total}" -eq 0 ]]; then
    requirements+=("requirements.yml")
    total="${#requirements[@]}"
    log.debug "Requirements are now: '${requirements[*]}'"
  fi
  idx=0
  log.info "Start YAML installations: collections from requirements files: ${requirements[*]}"
  for item in "${requirements[@]}"; do
    install_collection_from_yml "${item}" "${collections_path}"
    rc=$?
    log.debug "Installed collections from ${requirements[0]} with rc=${rc}"
    # pop the 1st requirement from requirements:
    idx=$((idx + 1))
  done
  test "${idx}" -eq 1 && val="" || val="s"
  log.info "End YAML installations: installed ${idx}[of ${total}] file${var}"
  idx=0
  # log.info "><> ><> ><> ><> ><> ><> should see python packages installed <>< <>< <>< <>< <>< <><"
  log.info "Start collecting of python requirements files"
  cmd=(find "${collections_path}" -name "meta" -type d -maxdepth 4)
  requirements=()
  while read -r sub_dir; do
    total=$((total + 1))
    log.debug "Testing collection meta sub_dir='${sub_dir}'"
    for item in "${sub_dir}/ee-requirements.txt" "${sub_dir}/requirements.txt"; do
      if ! [[ -r "${item}" ]]; then
        log.debug "Python requirements file ${item} is unreadable"
        continue
      fi
      requirements+=("${item}")
      log.debug "Added python requirements file ${item}"
      idx=$((idx + 1))
    done
  done < <("${cmd[@]}" -print || true)
  total="${#requirements[@]}"
  log.info "Collected ${total} python requirements files"
  log.info "Start installing python requirements"
  idx=0
  for item in "${requirements[@]}"; do
    py.reqs_install "${item}"
    idx=$((idx + 1))
  done
  test "${idx}" -eq 1 && val="" || val="s"
  log.info "End installing python requirements ${idx} [of ${total}] file${val}"
  epilog "${rc}"
  return "${rc}"
}

function lazy_collections_install() {
  local \
    item \
    collections_path \
    cache_path \
    recreate \
    var \
    val \
    rc
  local -a \
    reqs \
    vars
  prolog "${@}"
  collections_path="${1:-"${ANSIBLE_COLLECTIONS_PATH}"}"
  # take the 1st item if it has multiple items separated by :
  collections_path="${collections_path%%:*}"
  vars+=(collections_path)
  shift 1
  recreate="${1:-"${RECREATE}"}"
  vars+=(recreate)
  shift 1
  cache_path="${1:-"${CACHE_PATH}"}"
  vars+=(cache_path)
  shift 1
  reqs=("${@}")
  if [[ "${#reqs[@]}" -eq 0 ]]; then
    IFS=',' read -r -a reqs <<<"${COLLECTION_REQ_FILES_TXT}"
  fi
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  rc=0
  var=0
  if [[ "${recreate}" -gt 0 ]]; then
    log.info "Handle recreate=1"
    for item in "${collections_path}" "${cache_path}"; do
      val="Folder ${item} is missing. nothing to delete."
      if [[ -d "${item}" ]]; then
        rm -fr "${item}"
        val="Deleted ${item}. [REASON: recreate=${recreate}]"
      fi
      log.debug "${val}"
    done
  else
    log.info "Handle recreate=0"
    # if either is missing, don't return
    for item in "${collections_path}" "${cache_path}"; do
      if ! [[ -d "${item}" ]]; then
        var=$((var + 1))
      fi
    done
  fi
  log.info "Calculated var=${var}"
  if [[ "${var}" -eq 2 ]]; then
    log.info "Skip installations. [REASON: ${collections_path} and ${cache_path} are present and recreate=${recreate}]."
    return "${rc}"
  fi
  collections_install "${collections_path}" "${reqs[@]}"
  rc=$?
  test "${rc}" -eq 0 || die "${rc}" "Failed to install collections"
  epilog "${rc}"
  return "${rc}"
}

function action.bootstrap() {
  local \
    item \
    venv_dir \
    py \
    collections_path \
    cache_path \
    recreate \
    val \
    var \
    rc
  local -a \
    vars \
    reqs
  prolog "${@}"
  venv_dir="${1:-"${VENV_DIR}"}"
  vars+=(venv_dir)
  shift 1
  py="${1:-"${PY}"}"
  vars+=(py)
  shift 1
  collections_path="${1:-"${ANSIBLE_COLLECTIONS_PATH}"}"
  # take the 1st item if it has multiple items separated by :
  collections_path="${collections_path%%:*}"
  vars+=(collections_path)
  shift 1
  recreate="${1:-"${RECREATE}"}"
  vars+=(recreate)
  shift 1
  cache_path="${1:-"${CACHE_PATH}"}"
  vars+=(cache_path)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  reqs=("${@}")
  log.debug "=======> Accepted reqs: ${reqs[*]}"
  if [[ "${#reqs[@]}" -eq 0 ]]; then
    IFS=',' read -r -a reqs <<<"${COLLECTION_REQ_FILES_TXT}"
    log.debug "After adjusting reqs as it was empty"
  fi
  log.debug "=======> Adjusted reqs: ${reqs[*]}"
  venv.lazy_install "${venv_dir}" "${py}" "${recreate}"
  rc=$?
  log.debug "venv.lazy_install() returned rc=${rc}"
  if [[ "${DEV_MODE}" -gt 0 ]]; then
    if [[ "${#reqs[@]}" -eq 1 ]]; then
      reqs+=(requirements-dev.yml)
    fi
  fi
  lazy_collections_install "${collections_path}" "${recreate}" "${cache_path}" "${reqs[@]}"
  rc=$?

  log.debug "Outside ${FUNCNAME[0]}() returning rc=${rc}"
  return "${rc}"
}

function gendata() {
  local \
    item \
    venv_dir \
    data \
    generator \
    var \
    val \
    rc
  local -a \
    vars \
    cmd
  prolog "${@}"
  venv_dir="${1:-"${VENV_DIR}"}"
  vars+=(venv_dir)
  shift 1
  data="${1:-"${DATA_FILE}"}"
  vars+=(data)
  shift 1
  generator="${1:-"${GENERATOR}"}"
  vars+=(generator)
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  cmd=("python3" "${generator}" "--outfile=${data}")
  if [[ "${DEV_MODE}" -gt 0 ]]; then

    vars=("--skip-send")
    cmd+=("${vars[@]}")
    log.warn "Updating the command with dev flags: ${vars[*]}"
  fi
  run_cmd 0 "${cmd[@]}"
  rc=$?
  epilog "${rc}"
  return "${rc}"
}

function print_debug_var_name() {
  local \
    var_name \
    var_value
  var_name="${1?cannot continue without var_name}"
  var_value="$(eval echo "\$${var_name}" || true)"
  log.info "variable ${var_name}='${var_value}'"
}

function print_ci_type_detection_var() {
  local \
    ci_type \
    var_name \
    var_value
  ci_type="${1?cannot continue without ci_type}"
  case "${ci_type}" in
  "dci") var_name="DCI_CS_URL" ;;
  "jenkins") var_name="JENKINS_URL" ;;
  "github") var_name="GITHUB_API_URL" ;;
  "gitlab") var_name="GITLAB_CI" ;;
  "prow") var_name="PROW_JOB_ID" ;;
  *) die 1 "Bad name for ci_type: ${ci_type}" ;;
  esac
  log.info "ci_type='${ci_type}' ==> "
  print_debug_var_name "${var_name}"
}


function action.gendata() {
  local \
    item \
    venv_dir \
    data \
    generator \
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
  data="${1:-"${DATA_FILE}"}"
  vars+=(data)
  shift 1
  generator="${1:-"${GENERATOR}"}"
  vars+=(generator)
  shift 1
  recreate="${1:-"${RECREATE}"}"
  vars+=(recreate)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  if [[ -r "${data}" ]]; then
    if [[ "${recreate}" -eq 0 ]]; then
      log.debug "Skip data generation. [REASON: recreate=${recreate}]"
      return 0
    fi
  fi
  gendata "${venv_dir}" "${data}" "${generator}"
  rc=$?
  epilog "${rc}"
  return "${rc}"
}

function action.render() {
  local \
    item \
    venv_dir \
    extra_var \
    playbook \
    data_file \
    tpl_file \
    output_file \
    var \
    val \
    rc
  local -a \
    vars \
    cmd
  prolog "${@}"
  venv_dir="${1?cannot continue without venv_dir}"
  vars+=(venv_dir)
  shift 1
  data_file="${1:-"${DATA_FILE}"}"
  vars+=(data_file)
  shift 1
  tpl_file="${1:-"${TPL_FILE}"}"
  vars+=(tpl_file)
  shift 1
  output_file="${1:-"${EXTRA_VARS}"}"
  vars+=(output_file)

  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  venv.activate "${venv_dir}"
  val="$(dirname "${output_file}")"
  log.debug "Ensuring folder containing output_file exists: ${val}"
  mkdir -p "${val}"
  if [[ -r "${output_file}" ]]; then
    log.warn "Skip rendering. [REASON: Output file ${output_file} already exists]."
    return 1
  fi
  for var in "${data_file}" "${tpl_file}"; do
    if ! [[ -r "${var}" ]]; then
      log.error "Skip rendering. [REASON: ${var} file is not readable or missing]."
      return 1
    fi
  done
  cmd=(jinja "--format=yaml")
  cmd+=("--data=${data_file}")
  cmd+=("--output=${output_file}")
  cmd+=("${tpl_file}")
  run_cmd 0 "${cmd[@]}"
  rc=$?
  log.info "Extra variables file ${output_file} has been created successfully."
  log.info "Assuming your CI type is CI_TYPE=${CI_TYPE} (for full list see ))"
  log.info "you can run: 'make test CI_TYPE=${CI_TYPE}' (Assuming this is your CI type)"
  epilog "${rc}"
  return "${rc}"
}

function action.run_playbook() {
  local \
    item \
    extra_var \
    extra_param \
    venv_dir \
    playbook \
    extra_vars_txt \
    var \
    val \
    rc
  local -a \
    vars \
    extra_vars \
    extra_params \
    cmd
  prolog "${@}"
  venv_dir="${1:-"${VENV_DIR}"}"
  vars+=(venv_dir)
  shift 1
  playbook="${1:-"${PLAYBOOK}"}"
  vars+=(playbook)
  shift 1
  extra_vars_txt="${1:-""}"
  vars+=(extra_vars_txt)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  extra_params=("${@}")
  if [[ "${#extra_params[@]}" -eq 0 ]]; then
    extra_params=("${EXTRA_PARAMS[@]}")
  fi
  if [[ "${#extra_params[@]}" -ne 0 ]]; then
    log.debug "updated: extra_params: ${extra_params[*]}"
  fi
  for var in ANSIBLE_COLLECTIONS_PATH ANSIBLE_ROLES_PATH; do
    val="$(eval "echo \"\${${var}}\"")"
    log.debug "Checking environment ${var}: '${val}'"
  done
  IFS=',' read -r -a extra_vars <<<"${extra_vars_txt}"
  cmd+=(ansible-playbook -i localhost -c local)
  for extra_var in "${extra_vars[@]}"; do
    item="${extra_var}"
    test -r "${item}" && item="@${item}"
    cmd+=("-e" "${item}")
  done
  # log.debug "Current cmd: '${cmd[*]}'"
  log.debug "Updating cmd with: '${extra_params[*]}'"
  for extra_param in "${extra_params[@]}"; do
    cmd+=("${extra_param}")
  done
  # log.debug "Current cmd: '${cmd[*]}'"
  cmd+=("${playbook}")
  venv.activate "${venv_dir}"
  run_cmd 0 "${cmd[@]}"
  rc=$?
  epilog "${rc}"
  return "${rc}"
}

function action.test() {
  local \
    item \
    ci_type \
    venv_dir \
    env_file \
    extra_vars \
    playbook \
    var \
    rc
  local -a \
    vars
  prolog "${@}"
  venv_dir="${1:-"${VENV_DIR}"}"
  vars+=(venv_dir)
  shift 1
  playbook="${1:-"${PLAYBOOK}"}"
  vars+=(playbook)
  shift 1
  ci_type="${1:-"${CI_TYPE}"}"
  vars+=(ci_type)
  shift 1
  env_file="${1:-"${FIXTURES_ROOT}/${ci_type}/env.bash"}"
  vars+=(env_file)
  shift 1
  extra_vars="${1:-"${FIXTURES_ROOT}/${ci_type}/${PLAYBOOK}"}"
  vars+=(extra_vars)
  shift 1
  for var in "${vars[@]}"; do
    val="$(eval "echo \$${var}" || true)"
    test -n "${val}" && log.debug "updated: ${var}='${val}'"
  done
  print_ci_type_detection_var "${ci_type}"
  source_script "${env_file}"
  rc=$?
  test "${rc}" -eq 0 || die "${rc}" "Failed during ${env_file} execution (sourcing). please check your environment."
  log.debug "sourced ${env_file} with rc=${rc}"
  print_ci_type_detection_var "${ci_type}"
  log.info "About to run test environment for ci_type=${ci_type}, using extra_vars=${extra_vars}"
  action.run_playbook "${venv_dir}" "${playbook}" "${extra_vars}"
  rc=$?
  epilog "${rc}"
  return "${rc}"
}

function action.check_requirements() {
  local \
    rc \
    tmp_var \
    app
  local -a \
    apps
  apps=("${@}")
  if [[ "${#apps[@]}" -eq 0 ]]; then
    rc=0
    log.debug "Prematurely exiting. [REASON: nothing to check]."
    return "${rc}"
  fi
  rc=0
  for app in "${apps[@]}"; do
    log.debug "==> testing ${app}"
    if ! command -v "${app}" >/dev/null 2>&1; then
      rc=$?
      die "${rc}" "Application ${app} is not found on PATH. Please install it"
    fi
    tmp_var="$(command -v "${app}" || true)"
    log.debug "${app} location: '${tmp_var}'"
    tmp_var="$("${app}" --version || true)"
    log.debug "<== ${app} is installed"
    log.debug "version info: ${tmp_var}"
  done
  return "${rc}"
}

function action.reset_collections_reqs() {
  local \
    rc \
    src_reqs \
    del_collections \
    dst_reqs
  src_reqs="${1?cannot continue without src_reqs}"
  del_collections="${2?cannot continue without del_collections}"
  dst_reqs="${3:-"${src_reqs##*/}"}"
  log.debug "Copying ${src_reqs} ==> ${dst_reqs}"
  cp -p "${src_reqs}" "${dst_reqs}"
  log.debug "del_collections: ${del_collections}"
  if [[ "${del_collections}" != "" ]]; then
    log.debug "Collections to remove: ${del_collections}"
    run_cmd 0 "${PY}" ./tools/yaml_filter.py \
      --in-file="${src_reqs}" \
      --out-file="${dst_reqs}" \
      --del-names="${del_collections}"
    rc=$?
    if [[ "${rc}" -ne 0 ]]; then
      die "${rc}" "Failed to cleanup ${dst_reqs}"
    fi
    diff --color --unified "${src_reqs}" "${dst_reqs}" || true
  fi

}

function main() {
  local \
    action \
    rc
  local -a \
    reqs \
    debug_vars \
    args
  rc=0
  action="${1:-"bootstrap"}"
  log.info "Running action ${action}"
  # common args:
  args+=("${VENV_DIR}")

  debug_vars+=(
    SCRIPT_DBG
    DEV_MODE
    RECREATE
    PY
    VENV_DIR
    VARS_DIR
    # OUT_DIR
    # TPL_DIR
    # DATA_FILE
    # PLAYBOOK
    # GENERATOR
    # TPL_FILE
    EXTRA_VARS
    ANSIBLE_COLLECTIONS_PATH
    # CACHE_PATH
    CI_TYPE
    COLLECTION_ROOT
    COLLECTIONS_REQS_LOCAL
    COLLECTION_REQ_FILES_TXT
    # FIXTURES_ROOT
    TEST_DATA_DIR
    REQ_COLLECTIONS_ATTR
    # LIVE_FOREVER
  )

  if [[ "${SCRIPT_DBG}" -gt 0 ]]; then
    log.debug "Printing some debug VARIABLES:"
    for var_name in "${debug_vars[@]}"; do
      print_debug_var_name "${var_name}"
    done
  fi
  case "${action}" in
  "bootstrap")
    args+=("${PY}" "${ANSIBLE_COLLECTIONS_PATH}" "${RECREATE}" "${CACHE_PATH}")
    IFS=',' read -r -a reqs <<<"${COLLECTION_REQ_FILES_TXT}"
    log.debug "COLLECTION_REQ_FILES_TXT='${COLLECTION_REQ_FILES_TXT}'"
    log.debug "reqs: ${reqs[*]}"
    args+=("${reqs[@]}")
    time action.bootstrap "${args[@]}"
    rc=$?
    ;;
  # "buildpkg")
  #   args+=("${RECREATE}" "${COLLECTION_ROOT}" "${COLLECTIONS_REQS_LOCAL}")
  #   time action.buildpkg "${args[@]}"
  #   rc=$?
  #   ;;
  "check-requirements")
    shift 1
    time action.check_requirements "${@}"
    rc=$?
    ;;
  "gendata")
    args+=("${DATA_FILE}" "${GENERATOR}" "${RECREATE}")
    time action.gendata "${args[@]}"
    rc=$?
    ;;
  "render")
    args+=("${DATA_FILE}" "${TPL_FILE}" "${EXTRA_VARS}")
    time action.render "${args[@]}"
    rc=$?
    ;;
  "reset-collections-reqs")
    shift 1
    time action.reset_collections_reqs "${@}"
    rc=$?
    ;;
  "run-playbook")
    args+=("${PLAYBOOK}")
    time action.run_playbook "${args[@]}"
    rc=$?
    ;;
  "test")
    TEST_DATA_DIR="${TEST_DATA_DIR:-"${FIXTURES_ROOT}/${CI_TYPE}"}"
    args+=("${PLAYBOOK}" "${CI_TYPE}")
    args+=("${TEST_DATA_DIR}/env.bash")
    args+=("${TEST_DATA_DIR}/${PLAYBOOK}")
    time action.test "${args[@]}"
    rc=$?
    ;;
  *)
    help "${action}"
    exit 1
    ;;
  esac
  if [[ "${rc}" -ne 0 ]]; then
    log.error "The action='${action}' failed with rc=${rc}"
  fi
  return "${rc}"
}

if [[ "$0" = "${BASH_SOURCE:-""}" ]]; then
  main "${@}"
  RC=$?
fi
exit "${RC}"
