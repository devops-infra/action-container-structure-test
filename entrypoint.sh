#!/usr/bin/env bash

set -Eeuo pipefail

# Return code
RET_CODE=0

# Optional debug logging: pass `debug: true` in the action inputs to enable
[[ "${INPUT_DEBUG:-false}" == "true" ]] && set -x

info()  { printf "[INFO] ℹ️ %s\n" "$*"; }
#shellcheck disable=SC2329
warn()  { printf "[WARN] ⚠️ %s\n" "$*" >&2; }
#shellcheck disable=SC2329
error() { printf "[ERROR] ❌ %s\n" "$*" >&2; }

write_output() {
  local kv="$1"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf "%s\n" "${kv}" >> "${GITHUB_OUTPUT}"
  else
    info "[LOCAL] output -> ${kv}"
  fi
}

trap 'error "Action failed. Check logs above."' ERR

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
for cfg_file in "${CONFIG_FILES[@]}"; do
  CMD_ARGS+=(--config "${cfg_file}")
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
[[ -n "${METADATA}" ]]         && CMD_ARGS+=(--metadata "${METADATA}")
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
    cat "${TEST_REPORT}"
    # CST always writes JSON to report files
    parse_stats_json "${TEST_REPORT}"
  fi
else
  # Run normally and tee to a temp file for stats parsing
  TEMP_OUTPUT="$(mktemp /tmp/cst-output-XXXXXX.txt)"
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
