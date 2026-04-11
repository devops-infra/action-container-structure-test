#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/entrypoint.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$1"
}

assert_contains() {
  local needle="$1"
  local file="$2"
  if grep -Fq -- "${needle}" "${file}"; then
    return 0
  fi
  return 1
}

run_case() {
  local name="$1"
  local expect_rc="$2"
  shift 2

  local case_dir="${TMP_DIR}/${name}"
  mkdir -p "${case_dir}/bin"

  cat > "${case_dir}/bin/container-structure-test" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "version" ]]; then
  printf '1.22.1\n'
  exit 0
fi

output="text"
test_report=""
printf '%s\n' "$*" > "${FAKE_CST_ARGS_FILE}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output)
      output="$2"
      shift 2
      ;;
    --test-report)
      test_report="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "${test_report}" ]]; then
  if [[ "${output}" == "junit" ]]; then
    printf '<testsuite tests="5" failures="2"></testsuite>\n' > "${test_report}"
  else
    printf '{"Total":4,"Pass":3,"Fail":1}\n' > "${test_report}"
  fi
else
  case "${output}" in
    json)
      printf '{"Total":3,"Pass":2,"Fail":1}\n'
      ;;
    junit)
      printf '<testsuite tests="7" failures="3"></testsuite>\n'
      ;;
    *)
      printf 'Total tests: 6\nPasses: 5\nFailures: 1\n'
      ;;
  esac
fi

exit "${FAKE_CST_EXIT_CODE:-0}"
EOF

  chmod +x "${case_dir}/bin/container-structure-test"

  local output_file="${case_dir}/github_output.txt"
  local stdout_file="${case_dir}/stdout.txt"
  local stderr_file="${case_dir}/stderr.txt"
  local args_file="${case_dir}/args.txt"
  local cfg1="${case_dir}/one.yaml"
  local cfg2="${case_dir}/two.yaml"
  local report_file="${case_dir}/report.out"

  printf "schemaVersion: '2.0.0'\n" > "${cfg1}"
  printf "schemaVersion: '2.0.0'\n" > "${cfg2}"

  set +e
  (
    export PATH="${case_dir}/bin:${PATH}"
    export GITHUB_OUTPUT="${output_file}"
    export FAKE_CST_ARGS_FILE="${args_file}"
    export INPUT_IMAGE="sample:latest"
    export INPUT_CONFIG="${cfg1} ${cfg2}"
    export INPUT_DRIVER="docker"
    export INPUT_OUTPUT="text"
    export INPUT_PULL="false"
    export INPUT_SAVE="false"
    export INPUT_QUIET="false"
    export INPUT_NO_COLOR="false"
    export INPUT_FORCE="false"
    export INPUT_IGNORE_REF_ANNOTATION="false"
    export INPUT_DEBUG="false"
    "$@" "${ENTRYPOINT}"
  ) > "${stdout_file}" 2> "${stderr_file}"
  local rc=$?
  set -e

  if [[ "${rc}" -ne "${expect_rc}" ]]; then
    fail "${name} (expected rc=${expect_rc}, got ${rc})"
    return
  fi

  pass "${name}"
}

run_case missing-image 1 env -u INPUT_IMAGE -u INPUT_IMAGE_FROM_OCI_LAYOUT
run_case mutually-exclusive-image 1 env INPUT_IMAGE_FROM_OCI_LAYOUT="/tmp/oci"
run_case invalid-driver 1 env INPUT_DRIVER="podman"
run_case invalid-bool 1 env INPUT_PULL="yes"
run_case json-output 0 env INPUT_OUTPUT="json"
run_case junit-output-report 0 env INPUT_OUTPUT="junit" INPUT_TEST_REPORT="${TMP_DIR}/junit-report.xml"
run_case report-json 0 env INPUT_TEST_REPORT="${TMP_DIR}/json-report.json"

json_out="${TMP_DIR}/json-output/github_output.txt"
if assert_contains 'total=3' "${json_out}" && assert_contains 'passed=2' "${json_out}" && assert_contains 'failed=1' "${json_out}"; then
  pass 'json metrics parsing'
else
  fail 'json metrics parsing'
fi

junit_out="${TMP_DIR}/junit-output-report/github_output.txt"
if assert_contains 'total=5' "${junit_out}" && assert_contains 'passed=3' "${junit_out}" && assert_contains 'failed=2' "${junit_out}"; then
  pass 'junit report parsing'
else
  fail 'junit report parsing'
fi

report_out="${TMP_DIR}/report-json/github_output.txt"
if assert_contains 'total=4' "${report_out}" && assert_contains 'passed=3' "${report_out}" && assert_contains 'failed=1' "${report_out}"; then
  pass 'json report parsing'
else
  fail 'json report parsing'
fi

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  printf '\nTests failed: %s, passed: %s\n' "${FAIL_COUNT}" "${PASS_COUNT}"
  exit 1
fi

printf '\nAll tests passed: %s\n' "${PASS_COUNT}"
