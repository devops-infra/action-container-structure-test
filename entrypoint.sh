#!/usr/bin/env bash

set -Eeuo pipefail

RET_CODE=0
TMP_CLEANUP_FILES=()
CONFIG_TEMPLATE_PATTERN='\{\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\}\}'

[[ "${INPUT_DEBUG:-false}" == "true" ]] && set -x

info()  { printf "[INFO] %s\n" "$*"; }
# shellcheck disable=SC2329
warn()  { printf "[WARN] %s\n" "$*" >&2; }
# shellcheck disable=SC2329
error() { printf "[ERROR] %s\n" "$*" >&2; }

write_output() {
  local kv="$1"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf "%s\n" "${kv}" >> "${GITHUB_OUTPUT}"
  else
    info "[LOCAL] output -> ${kv}"
  fi
}

# shellcheck disable=SC2329
cleanup() {
  local file
  for file in "${TMP_CLEANUP_FILES[@]}"; do
    [[ -n "${file}" && -f "${file}" ]] && rm -f "${file}"
  done
}

trap cleanup EXIT

trap 'error "Action failed. Check logs above."' ERR

is_bool() {
  case "$1" in
    true|false) return 0 ;;
    *) return 1 ;;
  esac
}

validate_bool() {
  local name="$1"
  local value="$2"
  if ! is_bool "${value}"; then
    error "Invalid value for '${name}': '${value}'. Expected 'true' or 'false'."
    exit 1
  fi
}

validate_enum() {
  local name="$1"
  local value="$2"
  shift 2
  local allowed
  for allowed in "$@"; do
    if [[ "${value}" == "${allowed}" ]]; then
      return 0
    fi
  done
  error "Invalid value for '${name}': '${value}'. Allowed values: $*"
  exit 1
}

render_config_template() {
  local src_file="$1"
  local dst_file="$2"
  local content token var_name value
  local -a missing_vars=()

  content="$(cat "${src_file}")"

  while IFS= read -r token; do
    [[ -n "${token}" ]] || continue
    var_name="$(printf '%s' "${token}" | sed -E 's/^\{\{[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\}\}$/\1/')"
    if [[ ! -v "${var_name}" ]]; then
      missing_vars+=("${var_name}")
      continue
    fi
    value="${!var_name}"
    content="${content//${token}/${value}}"
  done < <(grep -oE "${CONFIG_TEMPLATE_PATTERN}" "${src_file}" | awk '!seen[$0]++')

  if [[ "${#missing_vars[@]}" -gt 0 ]]; then
    error "Unresolved config template variable(s) in ${src_file}: ${missing_vars[*]}"
    exit 1
  fi

  printf '%s' "${content}" > "${dst_file}"
}

rendered_config_suffix() {
  local src_file="$1"

  case "${src_file##*.}" in
    json)
      printf '.json'
      ;;
    yml)
      printf '.yml'
      ;;
    yaml)
      printf '.yaml'
      ;;
    *)
      printf '.yaml'
      ;;
  esac
}

create_rendered_config_path() {
  local src_file="$1"
  local base_path suffix target_path

  base_path="$(mktemp /tmp/cst-config-XXXXXX)"
  suffix="$(rendered_config_suffix "${src_file}")"
  target_path="${base_path}${suffix}"
  mv "${base_path}" "${target_path}"
  printf '%s' "${target_path}"
}

is_safe_host_tmp_path() {
  local path="$1"
  [[ "${path}" == /tmp/* ]] || return 1
  [[ "${path}" != *".."* ]] || return 1
  return 0
}

read_host_tmp_file() {
  local host_path="$1"
  local out_file="$2"
  local relative_path

  is_safe_host_tmp_path "${host_path}" || return 1
  command -v docker >/dev/null 2>&1 || return 1

  relative_path="${host_path#/tmp/}"
  docker run --rm -i -v /tmp:/hosttmp alpine:3.24.1 \
    sh -c "cat \"/hosttmp/${relative_path}\"" > "${out_file}" 2>/dev/null
}

write_host_tmp_file() {
  local in_file="$1"
  local host_path="$2"
  local relative_path

  is_safe_host_tmp_path "${host_path}" || return 1
  command -v docker >/dev/null 2>&1 || return 1
  [[ -f "${in_file}" ]] || return 1

  relative_path="${host_path#/tmp/}"
  docker run --rm -i -v /tmp:/hosttmp alpine:3.24.1 \
    sh -c "mkdir -p \"\$(dirname \"/hosttmp/${relative_path}\")\" && cat > \"/hosttmp/${relative_path}\"" \
    < "${in_file}" >/dev/null 2>&1
}

# Inputs
IMAGE="${INPUT_IMAGE:-}"
CONFIG="${INPUT_CONFIG:-}"
DRIVER="${INPUT_DRIVER:-docker}"
PLATFORM="${INPUT_PLATFORM:-}"
PULL="${INPUT_PULL:-false}"
SAVE="${INPUT_SAVE:-false}"
QUIET="${INPUT_QUIET:-false}"
NO_COLOR="${INPUT_NO_COLOR:-false}"
OUTPUT="${INPUT_OUTPUT:-text}"
TEST_REPORT="${INPUT_TEST_REPORT:-}"
JUNIT_SUITE_NAME="${INPUT_JUNIT_SUITE_NAME:-}"
METADATA="${INPUT_METADATA:-}"
RUNTIME="${INPUT_RUNTIME:-}"
FORCE="${INPUT_FORCE:-false}"
IMAGE_FROM_OCI_LAYOUT="${INPUT_IMAGE_FROM_OCI_LAYOUT:-}"
DEFAULT_IMAGE_TAG="${INPUT_DEFAULT_IMAGE_TAG:-}"
IGNORE_REF_ANNOTATION="${INPUT_IGNORE_REF_ANNOTATION:-false}"

info "Inputs:"
info "  image:                 ${IMAGE:+<set>}${IMAGE:-<empty>}"
info "  config:                ${CONFIG:+<set>}${CONFIG:-<empty>}"
info "  driver:                ${DRIVER}"
info "  platform:              ${PLATFORM:-<default>}"
info "  pull:                  ${PULL}"
info "  save:                  ${SAVE}"
info "  quiet:                 ${QUIET}"
info "  no_color:              ${NO_COLOR}"
info "  output:                ${OUTPUT}"
info "  test_report:           ${TEST_REPORT:-<none>}"
info "  junit_suite_name:      ${JUNIT_SUITE_NAME:-<none>}"
info "  metadata:              ${METADATA:-<none>}"
info "  runtime:               ${RUNTIME:-<default>}"
info "  force:                 ${FORCE}"
info "  image_from_oci_layout: ${IMAGE_FROM_OCI_LAYOUT:-<none>}"
info "  default_image_tag:     ${DEFAULT_IMAGE_TAG:-<none>}"
info "  ignore_ref_annotation: ${IGNORE_REF_ANNOTATION}"

# Validate required inputs
if [[ -z "${IMAGE}" && -z "${IMAGE_FROM_OCI_LAYOUT}" ]]; then
  error "Missing required input: 'image' or 'image_from_oci_layout' must be provided."
  exit 1
fi

if [[ -n "${IMAGE}" && -n "${IMAGE_FROM_OCI_LAYOUT}" ]]; then
  error "Inputs 'image' and 'image_from_oci_layout' are mutually exclusive."
  exit 1
fi

if [[ -z "${CONFIG}" ]]; then
  error "Missing required input: 'config' must be provided."
  exit 1
fi

validate_enum "driver" "${DRIVER}" docker tar host
validate_enum "output" "${OUTPUT}" text json junit
validate_bool "pull" "${PULL}"
validate_bool "save" "${SAVE}"
validate_bool "quiet" "${QUIET}"
validate_bool "no_color" "${NO_COLOR}"
validate_bool "force" "${FORCE}"
validate_bool "ignore_ref_annotation" "${IGNORE_REF_ANNOTATION}"

if [[ -n "${DEFAULT_IMAGE_TAG}" && -z "${IMAGE_FROM_OCI_LAYOUT}" ]]; then
  error "Input 'default_image_tag' requires 'image_from_oci_layout'."
  exit 1
fi

if [[ "${IGNORE_REF_ANNOTATION}" == "true" && -z "${IMAGE_FROM_OCI_LAYOUT}" ]]; then
  error "Input 'ignore_ref_annotation' requires 'image_from_oci_layout'."
  exit 1
fi

if [[ -n "${JUNIT_SUITE_NAME}" && "${OUTPUT}" != "junit" ]]; then
  error "Input 'junit_suite_name' can only be used when output is 'junit'."
  exit 1
fi

if [[ -n "${RUNTIME}" && "${DRIVER}" != "docker" ]]; then
  error "Input 'runtime' can only be used with driver 'docker'."
  exit 1
fi

if [[ "${PULL}" == "true" && "${DRIVER}" != "docker" ]]; then
  error "Input 'pull' can only be used with driver 'docker'."
  exit 1
fi

# Build command arguments
CMD_ARGS=("test")

# Add image or OCI layout
if [[ -n "${IMAGE}" ]]; then
  CMD_ARGS+=(--image "${IMAGE}")
else
  CMD_ARGS+=(--image-from-oci-layout "${IMAGE_FROM_OCI_LAYOUT}")
  [[ -n "${DEFAULT_IMAGE_TAG}" ]] && CMD_ARGS+=(--default-image-tag "${DEFAULT_IMAGE_TAG}")
  [[ "${IGNORE_REF_ANNOTATION}" == "true" ]] && CMD_ARGS+=(--ignore-ref-annotation)
fi

# Add config files, supporting space- and newline-separated lists
mapfile -t CONFIG_FILES < <(printf '%s' "${CONFIG}" | tr -s '[:space:]' '\n' | grep -v '^[[:space:]]*$')
if [[ "${#CONFIG_FILES[@]}" -eq 0 ]]; then
  error "Input 'config' did not contain any valid file paths."
  exit 1
fi

for cfg_file in "${CONFIG_FILES[@]}"; do
  if [[ ! -f "${cfg_file}" ]]; then
    error "Config file not found: ${cfg_file}"
    exit 1
  fi
  if grep -qE "${CONFIG_TEMPLATE_PATTERN}" "${cfg_file}"; then
    rendered_cfg="$(create_rendered_config_path "${cfg_file}")"
    render_config_template "${cfg_file}" "${rendered_cfg}"
    TMP_CLEANUP_FILES+=("${rendered_cfg}")
    info "Rendered config template: ${cfg_file} -> ${rendered_cfg}"
    CMD_ARGS+=(--config "${rendered_cfg}")
  else
    CMD_ARGS+=(--config "${cfg_file}")
  fi
done

# Add optional flags
CMD_ARGS+=(--driver "${DRIVER}")
[[ -n "${PLATFORM}" ]]       && CMD_ARGS+=(--platform "${PLATFORM}")
[[ "${PULL}" == "true" ]]    && CMD_ARGS+=(--pull)
[[ "${SAVE}" == "true" ]]    && CMD_ARGS+=(--save)
[[ "${QUIET}" == "true" ]]   && CMD_ARGS+=(--quiet)
[[ "${NO_COLOR}" == "true" ]] && CMD_ARGS+=(--no-color)
CMD_ARGS+=(--output "${OUTPUT}")
[[ -n "${JUNIT_SUITE_NAME}" ]] && CMD_ARGS+=(--junit-suite-name "${JUNIT_SUITE_NAME}")

if [[ -n "${METADATA}" ]]; then
  if [[ -n "${IMAGE}" ]]; then
    warn "Input 'metadata' is ignored when 'image' is set because container-structure-test rejects this combination."
  else
    EFFECTIVE_METADATA="${METADATA}"
    if [[ ! -f "${EFFECTIVE_METADATA}" && "${METADATA}" == /tmp/* ]]; then
      TEMP_METADATA_FILE="$(mktemp /tmp/cst-metadata-XXXXXX.json)"
      if read_host_tmp_file "${METADATA}" "${TEMP_METADATA_FILE}"; then
        info "Loaded metadata from host temporary path: ${METADATA}"
        EFFECTIVE_METADATA="${TEMP_METADATA_FILE}"
        TMP_CLEANUP_FILES+=("${TEMP_METADATA_FILE}")
      else
        rm -f "${TEMP_METADATA_FILE}"
      fi
    fi

    if [[ ! -f "${EFFECTIVE_METADATA}" ]]; then
      error "Metadata file not found: ${METADATA}"
      exit 1
    fi

    CMD_ARGS+=(--metadata "${EFFECTIVE_METADATA}")
  fi
fi

[[ -n "${RUNTIME}" ]]          && CMD_ARGS+=(--runtime "${RUNTIME}")
[[ "${FORCE}" == "true" ]]     && CMD_ARGS+=(--force)

info "Running: container-structure-test ${CMD_ARGS[*]}"

# Initialize stats
CST_EXIT_CODE=0
TOTAL=0
PASSED=0
FAILED=0

# Parse stats from a captured JSON/text/junit output file
parse_stats_json() {
  local file="$1"
  if jq -e . "${file}" > /dev/null 2>&1; then
    TOTAL=$(jq -r '.Total // 0' "${file}")
    PASSED=$(jq -r '.Pass  // 0' "${file}")
    FAILED=$(jq -r '.Fail  // 0' "${file}")
  fi
}

parse_stats_text() {
  local file="$1"
  TOTAL=$(grep -oE 'Total tests:[[:space:]]+[0-9]+' "${file}" | tail -1 | grep -oE '[0-9]+' || echo "0")
  PASSED=$(grep -oE 'Passes:[[:space:]]+[0-9]+'      "${file}" | tail -1 | grep -oE '[0-9]+' || echo "0")
  FAILED=$(grep -oE 'Failures:[[:space:]]+[0-9]+'    "${file}" | tail -1 | grep -oE '[0-9]+' || echo "0")
  TOTAL="${TOTAL:-0}"
  PASSED="${PASSED:-0}"
  FAILED="${FAILED:-0}"
}

parse_stats_junit() {
  local file="$1"
  TOTAL=$(grep -oE 'tests="[0-9]+"'    "${file}" | tail -1 | grep -oE '[0-9]+' || echo "0")
  FAILED=$(grep -oE 'failures="[0-9]+"' "${file}" | tail -1 | grep -oE '[0-9]+' || echo "0")
  TOTAL="${TOTAL:-0}"
  FAILED="${FAILED:-0}"
  PASSED=$(( TOTAL - FAILED ))
}

if [[ -n "${TEST_REPORT}" ]]; then
  # When --test-report is provided, CST redirects all output to the file
  # (CST also converts text format to json automatically)
  CMD_ARGS+=(--test-report "${TEST_REPORT}")
  trap - ERR
  set +e
  container-structure-test "${CMD_ARGS[@]}"
  CST_EXIT_CODE=$?
  set -e
  trap 'error "Action failed. Check logs above."' ERR

  if [[ -f "${TEST_REPORT}" ]]; then
    info "Test report written to: ${TEST_REPORT}"
    info "Test report content:"
    cat "${TEST_REPORT}"
    case "${OUTPUT}" in
      junit) parse_stats_junit "${TEST_REPORT}" ;;
      *)     parse_stats_json "${TEST_REPORT}" ;;
    esac

    if [[ "${TEST_REPORT}" == /tmp/* ]]; then
      if write_host_tmp_file "${TEST_REPORT}" "${TEST_REPORT}"; then
        info "Mirrored test report to host temporary path: ${TEST_REPORT}"
      else
        warn "Unable to mirror test report to host temporary path: ${TEST_REPORT}"
      fi
    fi
  else
    warn "Expected test report file was not created: ${TEST_REPORT}"
  fi
else
  # Run normally and tee to a temp file for stats parsing
  TEMP_OUTPUT="$(mktemp /tmp/cst-output-XXXXXX)"
  trap - ERR
  set +e
  container-structure-test "${CMD_ARGS[@]}" 2>&1 | tee "${TEMP_OUTPUT}"
  CST_EXIT_CODE="${PIPESTATUS[0]}"
  set -e
  trap 'error "Action failed. Check logs above."' ERR

  if [[ -f "${TEMP_OUTPUT}" ]]; then
    case "${OUTPUT}" in
      json)  parse_stats_json  "${TEMP_OUTPUT}" ;;
      junit) parse_stats_junit "${TEMP_OUTPUT}" ;;
      *)     parse_stats_text  "${TEMP_OUTPUT}" ;;
    esac
    rm -f "${TEMP_OUTPUT}"
  fi
fi

info "Results: Total=${TOTAL}, Passed=${PASSED}, Failed=${FAILED}, ExitCode=${CST_EXIT_CODE}"

# Set outputs
write_output "total=${TOTAL}"
write_output "passed=${PASSED}"
write_output "failed=${FAILED}"
write_output "exit_code=${CST_EXIT_CODE}"

info "Completed."
RET_CODE=${CST_EXIT_CODE}
exit "${RET_CODE}"
