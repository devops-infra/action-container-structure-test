#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENTRYPOINT="${ROOT_DIR}/entrypoint.sh"

TMP_DIR="$(mktemp -d)"
HOST_TMP_METADATA="/tmp/cst-metadata-${$}.json"
trap 'rm -rf "${TMP_DIR}"; rm -f "${HOST_TMP_METADATA}"' EXIT

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

assert_regex() {
  local pattern="$1"
  local file="$2"
  if grep -Eq -- "${pattern}" "${file}"; then
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
configs=()
printf '%s\n' "$*" > "${FAKE_CST_ARGS_FILE}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --config)
      configs+=("$2")
      shift 2
      ;;
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

if [[ -n "${FAKE_CST_CONFIG_DUMP_DIR:-}" ]]; then
  idx=1
  for cfg in "${configs[@]}"; do
    cp "${cfg}" "${FAKE_CST_CONFIG_DUMP_DIR}/config-${idx}.yaml"
    idx=$((idx + 1))
  done
fi

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

  cat > "${case_dir}/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="$*"
if [[ "${cmd}" =~ /hosttmp/([^\"[:space:]]+) ]]; then
  rel_path="${BASH_REMATCH[1]}"
  host_path="/tmp/${rel_path}"

  if [[ "${cmd}" == *"cat >"* ]]; then
    mkdir -p "$(dirname "${host_path}")"
    cat > "${host_path}"
    exit 0
  fi

  if [[ -f "${host_path}" ]]; then
    cat "${host_path}"
    exit 0
  fi
fi

exit 1
EOF

  chmod +x "${case_dir}/bin/container-structure-test"
  chmod +x "${case_dir}/bin/docker"

  local output_file="${case_dir}/github_output.txt"
  local stdout_file="${case_dir}/stdout.txt"
  local stderr_file="${case_dir}/stderr.txt"
  local args_file="${case_dir}/args.txt"
  local config_dump_dir="${case_dir}/rendered-configs"
  local cfg1="${case_dir}/one.yaml"
  local cfg2="${case_dir}/two.yaml"
  mkdir -p "${config_dump_dir}"
  printf "schemaVersion: '2.0.0'\n" > "${cfg1}"
  printf "schemaVersion: '2.0.0'\n" > "${cfg2}"
  case "${name}" in
    config-template-render)
      cat > "${cfg1}" <<'EOF'
schemaVersion: '2.0.0'
commandTests:
  - name: Example
    command: bash
    envVars:
      - key: EXPECTED_VERSION
        value: '{{TEMPLATE_VALUE}}'
    args:
      - -lc
      - test "${EXPECTED_VERSION}" = "{{TEMPLATE_VALUE}}" && test "${INNER_SHELL_VAR}" = "outer-value"
EOF
      ;;
    config-template-missing-var)
      cat > "${cfg1}" <<'EOF'
schemaVersion: '2.0.0'
commandTests:
  - name: Missing
    command: bash
    args:
      - -lc
      - test 'x' = '{{MISSING_VALUE}}'
EOF
      ;;
  esac

  set +e
  (
    export PATH="${case_dir}/bin:${PATH}"
    export GITHUB_OUTPUT="${output_file}"
    export FAKE_CST_ARGS_FILE="${args_file}"
    export FAKE_CST_CONFIG_DUMP_DIR="${config_dump_dir}"
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
run_case default-image-tag-without-oci 1 env -u INPUT_IMAGE_FROM_OCI_LAYOUT INPUT_DEFAULT_IMAGE_TAG="latest"
run_case default-image-tag-with-oci 0 env -u INPUT_IMAGE INPUT_IMAGE_FROM_OCI_LAYOUT="/tmp/oci-layout" INPUT_DEFAULT_IMAGE_TAG="latest"
run_case junit-suite-name-without-junit-output 1 env INPUT_JUNIT_SUITE_NAME="suite-a"
run_case junit-suite-name-with-junit-output 0 env INPUT_OUTPUT="junit" INPUT_JUNIT_SUITE_NAME="suite-a"

printf '{"config":{"Env":["FOO=bar"]}}\n' > "${HOST_TMP_METADATA}"
run_case metadata-file-not-found 1 env -u INPUT_IMAGE INPUT_IMAGE_FROM_OCI_LAYOUT="/tmp/oci-layout" INPUT_METADATA="/tmp/cst-metadata-not-found-${$}.json"
run_case metadata-host-tmp 0 env -u INPUT_IMAGE INPUT_IMAGE_FROM_OCI_LAYOUT="/tmp/oci-layout" INPUT_METADATA="${HOST_TMP_METADATA}"
run_case metadata-with-image 0 env INPUT_METADATA="${HOST_TMP_METADATA}"
run_case config-template-render 0 env TEMPLATE_VALUE="2.87.0" INNER_SHELL_VAR="outer-value"
run_case config-template-missing-var 1 env

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

default_image_tag_err="${TMP_DIR}/default-image-tag-without-oci/stderr.txt"
if assert_contains "Input 'default_image_tag' requires 'image_from_oci_layout'." "${default_image_tag_err}"; then
  pass 'default_image_tag validation'
else
  fail 'default_image_tag validation'
fi

default_image_tag_args="${TMP_DIR}/default-image-tag-with-oci/args.txt"
if assert_contains '--image-from-oci-layout /tmp/oci-layout' "${default_image_tag_args}" && assert_contains '--default-image-tag latest' "${default_image_tag_args}"; then
  pass 'default_image_tag with oci args'
else
  fail 'default_image_tag with oci args'
fi

junit_suite_name_err="${TMP_DIR}/junit-suite-name-without-junit-output/stderr.txt"
if assert_contains "Input 'junit_suite_name' can only be used when output is 'junit'." "${junit_suite_name_err}"; then
  pass 'junit_suite_name validation'
else
  fail 'junit_suite_name validation'
fi

junit_suite_name_args="${TMP_DIR}/junit-suite-name-with-junit-output/args.txt"
if assert_contains '--output junit' "${junit_suite_name_args}" && assert_contains '--junit-suite-name suite-a' "${junit_suite_name_args}"; then
  pass 'junit_suite_name with junit args'
else
  fail 'junit_suite_name with junit args'
fi

metadata_missing_err="${TMP_DIR}/metadata-file-not-found/stderr.txt"
if assert_contains "Metadata file not found: /tmp/cst-metadata-not-found-${$}.json" "${metadata_missing_err}"; then
  pass 'metadata missing validation'
else
  fail 'metadata missing validation'
fi

metadata_args="${TMP_DIR}/metadata-host-tmp/args.txt"
if assert_regex '--metadata /tmp/cst-metadata-[^[:space:]]+\.json' "${metadata_args}"; then
  pass 'metadata host tmp fallback'
else
  fail 'metadata host tmp fallback'
fi

metadata_with_image_args="${TMP_DIR}/metadata-with-image/args.txt"
if ! assert_contains '--metadata ' "${metadata_with_image_args}"; then
  pass 'metadata ignored with image'
else
  fail 'metadata ignored with image'
fi

metadata_with_image_err="${TMP_DIR}/metadata-with-image/stderr.txt"
if assert_contains "Input 'metadata' is ignored when 'image' is set" "${metadata_with_image_err}"; then
  pass 'metadata ignored warning with image'
else
  fail 'metadata ignored warning with image'
fi

template_rendered_cfg="${TMP_DIR}/config-template-render/rendered-configs/config-1.yaml"
if assert_contains "value: '2.87.0'" "${template_rendered_cfg}" && assert_contains "test \"\${EXPECTED_VERSION}\" = \"2.87.0\"" "${template_rendered_cfg}" && assert_contains "test \"\${INNER_SHELL_VAR}\" = \"outer-value\"" "${template_rendered_cfg}"; then
  pass 'config template rendering'
else
  fail 'config template rendering'
fi

template_missing_err="${TMP_DIR}/config-template-missing-var/stderr.txt"
if assert_contains 'Unresolved config template variable(s)' "${template_missing_err}" && assert_contains 'MISSING_VALUE' "${template_missing_err}"; then
  pass 'config template missing var validation'
else
  fail 'config template missing var validation'
fi

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  printf '\nTests failed: %s, passed: %s\n' "${FAIL_COUNT}" "${PASS_COUNT}"
  exit 1
fi

printf '\nAll tests passed: %s\n' "${PASS_COUNT}"
