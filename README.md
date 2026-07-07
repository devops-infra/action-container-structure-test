# 🚀 Container Structure Test
**GitHub Action running Google Container Structure Tests against a container image**


## 📦 Available on
- **Docker Hub:** [devopsinfra/action-container-structure-test:latest](https://hub.docker.com/repository/docker/devopsinfra/action-container-structure-test)
- **GitHub Packages:** [ghcr.io/devops-infra/action-container-structure-test:latest](https://github.com/devops-infra/action-container-structure-test/pkgs/container/action-container-structure-test)


## ✨ Features
* Runs [GoogleContainerTools/container-structure-test](https://github.com/GoogleContainerTools/container-structure-test) in CI
* Supports all test types: command tests, file existence tests, file content tests, metadata tests, license tests
* Supports `docker`, `tar`, and `host` drivers
* Renders `{{VAR_NAME}}` placeholders in test configs from the GitHub Actions job environment before executing CST
* Exposes test totals (total / passed / failed) as Action outputs
* Multi-platform image: `linux/amd64` and `linux/arm64`
* Lightweight Alpine-based Docker image


## 🔗 Related Actions
Check also other actions from [DevOps-Infra](https://shyper.pro/portfolio/projects/actions/)


## 📊 Badges
[
![GitHub repo](https://img.shields.io/badge/GitHub-devops--infra%2Faction--container--structure--test-blueviolet.svg?style=plastic&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/devops-infra/action-container-structure-test?color=blueviolet&logo=github&style=plastic&label=Last%20commit)
![Pull Request](https://github.com/devops-infra/action-container-structure-test/actions/workflows/auto-pull-request-create.yml/badge.svg)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/devops-infra/action-container-structure-test?color=blueviolet&label=Code%20size&style=plastic&logo=github)
![GitHub license](https://img.shields.io/github/license/devops-infra/action-container-structure-test?color=blueviolet&logo=github&style=plastic&label=License)
](https://github.com/devops-infra/action-container-structure-test "shields.io")
<br>
[
![DockerHub](https://img.shields.io/badge/DockerHub-devopsinfra%2Faction--container--structure--test-blue.svg?style=plastic&logo=docker)
![Docker version](https://img.shields.io/docker/v/devopsinfra/action-container-structure-test?color=blue&label=Version&logo=docker&style=plastic&sort=semver)
![Image size](https://img.shields.io/docker/image-size/devopsinfra/action-container-structure-test/latest?label=Image%20size&style=plastic&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/devopsinfra/action-container-structure-test?color=blue&label=Pulls&logo=docker&style=plastic)
![Weekly Health](https://github.com/devops-infra/action-container-structure-test/actions/workflows/cron-dependency-update.yml/badge.svg)
](https://hub.docker.com/r/devopsinfra/action-container-structure-test "shields.io")


## 🏷️ Version Tags: vX, vX.Y, vX.Y.Z
This action supports three tag levels for flexible versioning:
- `vX`: latest patch of the major version (e.g., `v1`).
- `vX.Y`: latest patch of the minor version (e.g., `v1.0`).
- `vX.Y.Z`: fixed to a specific release (e.g., `v1.0.0`).


## 📖 API Reference
```yaml
    - name: Run the Action
      uses: devops-infra/action-container-structure-test@v1.0.6
      with:
        image: my-image:latest
        config: tests/structure-test.yaml
        driver: docker
        output: text
        debug: false
```

### 🔧 Input Parameters
| Input                   | Required | Default  | Description                                                                                                                                       |
|:------------------------|:--------:|:--------:|:--------------------------------------------------------------------------------------------------------------------------------------------------|
| `image`                 |    *     |          | Image to test. Required unless `image_from_oci_layout` is set. Mutually exclusive with it.                                                        |
| `config`                |   Yes    |          | Path(s) to test config file(s). Space or newline-separated for multiple files. `{{VAR_NAME}}` placeholders are rendered from the job environment. |
| `driver`                |    No    | `docker` | Driver to use when running tests: `docker`, `tar`, or `host`.                                                                                     |
| `platform`              |    No    |          | Platform to test, e.g. `linux/amd64` or `linux/arm64`. Defaults to host arch.                                                                     |
| `pull`                  |    No    | `false`  | Force pull the image before running tests (docker driver only).                                                                                   |
| `save`                  |    No    | `false`  | Preserve created containers after the test run.                                                                                                   |
| `quiet`                 |    No    | `false`  | Suppress test output.                                                                                                                             |
| `no_color`              |    No    | `false`  | Disable colorized output.                                                                                                                         |
| `output`                |    No    |  `text`  | Output format: `text`, `json`, or `junit`.                                                                                                        |
| `test_report`           |    No    |          | Write test results to this file path, then print it to logs. CST converts `text` to `json` automatically.                                         |
| `junit_suite_name`      |    No    |          | Name for the JUnit test suite (only used when `output` is `junit`).                                                                               |
| `metadata`              |    No    |          | Path to image metadata file.                                                                                                                      |
| `runtime`               |    No    |          | Runtime to use with the docker driver (e.g. `runsc` for gVisor).                                                                                  |
| `force`                 |    No    | `false`  | Force run of host driver without interactive prompt.                                                                                              |
| `image_from_oci_layout` |    No    |          | Path to OCI image layout directory. Mutually exclusive with `image`.                                                                              |
| `default_image_tag`     |    No    |          | Default image tag when OCI layout lacks a ref annotation. Requires `image_from_oci_layout`.                                                       |
| `ignore_ref_annotation` |    No    | `false`  | Ignore `org.opencontainers.image.ref.name` annotation when loading OCI layout.                                                                    |
| `debug`                 |    No    | `false`  | Enable verbose debug logging in the action entrypoint.                                                                                            |


### 📤 Output Parameters
| Output      | Description                                          |
|:------------|:-----------------------------------------------------|
| `total`     | Total number of tests executed.                      |
| `passed`    | Number of tests that passed.                         |
| `failed`    | Number of tests that failed.                         |
| `exit_code` | Exit code returned by `container-structure-test`.    |


## 💻 Usage Examples

### 📝 Basic Example
Run structure tests against a Docker image using a single config file.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build image
        run: docker build -t my-image:latest .

      - uses: devops-infra/action-container-structure-test@v1
        with:
          image: my-image:latest
          config: tests/structure-test.yaml
```

### 🔀 Advanced Example
Run tests with multiple config files, JSON output, and a saved report.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build image
        run: docker build -t my-image:latest .

      - name: Run structure tests
        id: cst
        uses: devops-infra/action-container-structure-test@v1
        with:
          image: my-image:latest
          config: |
            tests/command-tests.yaml
            tests/file-tests.yaml
          output: json
          test_report: /tmp/cst-report.json
          pull: 'false'
          debug: 'false'

      - name: Show test results
        run: |
          echo "Total:  ${{ steps.cst.outputs.total }}"
          echo "Passed: ${{ steps.cst.outputs.passed }}"
          echo "Failed: ${{ steps.cst.outputs.failed }}"
          echo "Exit:   ${{ steps.cst.outputs.exit_code }}"
```

### 🎯 Use specific version
Pick the tag level based on your stability needs:
- `vX.Y.Z`: exact immutable release (most predictable)
- `vX.Y`: latest patch within one minor line
- `vX`: latest patch within one major line

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: devops-infra/action-container-structure-test@v1.0.6
        id: pin-patch-version
        with:
          image: my-image:latest
          config: tests/structure-test.yaml

      - uses: devops-infra/action-container-structure-test@v1.0
        id: pin-minor-version
        with:
          image: my-image:latest
          config: tests/structure-test.yaml

      - uses: devops-infra/action-container-structure-test@v1
        id: pin-major-version
        with:
          image: my-image:latest
          config: tests/structure-test.yaml
```

### 🧪 JUnit Output
Generate a JUnit report for test result publishing.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build image
        run: docker build -t my-image:latest .

      - name: Run structure tests
        uses: devops-infra/action-container-structure-test@v1
        with:
          image: my-image:latest
          config: tests/structure-test.yaml
          output: junit
          junit_suite_name: container-structure-tests
          test_report: /tmp/cst-results.xml
```

### 📦 TAR Driver
Test an exported image without a Docker daemon (file/metadata tests only).

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Export image as tar
        run: docker save my-image:latest -o my-image.tar

      - uses: devops-infra/action-container-structure-test@v1
        with:
          image: my-image.tar
          config: tests/file-tests.yaml
          driver: tar
```


## 📋 Test Config Reference

Container Structure Test configs are YAML or JSON files.
The current schema version is `2.0.0` and must be set in every config.

The action renders `{{VAR_NAME}}` placeholders in config files before calling CST.
Use this for workflow-controlled values such as versions exported into `GITHUB_ENV`.
Keep `${VAR}` syntax for shell expansion that should happen inside the tested container.

Example:

```yaml
commandTests:
  - name: Azure CLI
    command: bash
    args:
      - -lc
      - test "$(az version --output json | jq -r '."azure-cli"')" = '{{AZ_VERSION}}'
```

```yaml
schemaVersion: '2.0.0'

commandTests:
  - name: "python version"
    command: "python3"
    args: ["--version"]
    expectedOutput: ["Python 3\\..*"]

fileExistenceTests:
  - name: "entrypoint exists"
    path: "/entrypoint.sh"
    shouldExist: true
    permissions: "-rwxr-xr-x"

fileContentTests:
  - name: "sources list"
    path: "/etc/os-release"
    expectedContents: [".*alpine.*"]

metadataTest:
  workdir: "/app"
  envVars:
    - key: PATH
      value: "/usr/local/bin:.*"
      isRegex: true
```

Full documentation: [GoogleContainerTools/container-structure-test](https://github.com/GoogleContainerTools/container-structure-test)


## 🏗️ CI/CD
Workflows included:
- (Auto) Pull Request Create (`.github/workflows/auto-pull-request-create.yml`)
  - Trigger: push to any branch except `master` and `dependabot/**`.
  - Jobs:
    - Lint
    - Build and push multi-platform test image, and inspect manifest
    - Create pull request
- (Auto) Create release (`.github/workflows/auto-create-release.yml`)
  - Trigger: `pull_request` closed and `push` to `release/**` (runs only for merged PRs from `release/`)
  - Jobs:
    - Lint
    - Tagging: create `vX.Y.Z`; update `vX.Y` and `vX` (fails if full tag exists on remote)
    - Build and push multi-platform image, and inspect manifest
    - Publish GitHub Release
    - Update Docker hub description
- (Cron) Weekly dependency build (`.github/workflows/cron-dependency-update.yml`)
  - Trigger: Weekly on Monday at 08:00 UTC
  - Jobs:
    - Lint
    - Build and push multi-platform test image, and inspect manifest
- (Manual) Prepare release branch (`.github/workflows/manual-release-branch-prepare.yml`)
  - Trigger: manual `workflow_dispatch` with `type` (`patch|minor|major|set`) xor `version` when `type=set`
  - Creates `release/vX.Y.Z`, builds/pushes the `-rc` image, and opens the release PR
  - Merge that PR to trigger `.github/workflows/auto-release-create.yml`, which tags and publishes the final release
  - Jobs:
    - Update version: bump or set; output `REL_VERSION`
    - Build and push multi-platform `-rc` image, and inspect manifest
    - Create pull request for the final release merge


## 🧑‍💻 Development
Prerequisites:
- Docker with Buildx,
- Task (installed via workflow or from https://taskfile.dev),
- gnu-sed if on macOS (`brew install gnu-sed`),
- pre-commit (optional).

Common tasks:
```bash
# Run all linters
task lint

# Build multi-arch images locally (no push)
task docker:build

# Build a local runnable image for your current architecture
task docker:build:local

# Run container-structure-test action locally (build is required and enforced)
task docker:test:local IMAGE=my-image:latest CONFIG=tests/structure-test.yaml

# Run with multiple config files
task docker:test:local IMAGE=my-image:latest CONFIG="tests/command-tests.yaml tests/file-tests.yaml"

# Run against OCI layout
task docker:test:local IMAGE_FROM_OCI_LAYOUT=./oci-layout CONFIG=tests/structure-test.yaml

# Run built-in smoke test against the locally built action image
task docker:test:smoke

# Push images (requires DOCKER_TOKEN and GITHUB_TOKEN)
DOCKER_TOKEN=... GITHUB_TOKEN=... task docker:push
```

Local run notes:
- `docker:test:local` always builds the action image first via `docker:build:local`.
- `docker:test:smoke` uses `tests/docker/local-image.yml` to verify installed binaries,
  metadata, and cache cleanup on the built image.
- For `DRIVER=docker` (default), Docker socket access is required.
- Optional task variables map to action inputs, for example:
  - `OUTPUT=json`, `PULL=true`, `PLATFORM=linux/arm64`, `DEBUG=true`

Pre-commit hooks:
```bash
brew install pre-commit
task pre-commit:install
task pre-commit
```


## 🤝 Contributing
Contributions are welcome! See [CONTRIBUTING](https://github.com/devops-infra/.github/blob/master/CONTRIBUTING.md).
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 💬 Support
If you have any questions or need help, please:
- 📝 Create an [issue](https://github.com/devops-infra/action-container-structure-test/issues)
- 🌟 Star this repository if you find it useful!

## 🧪 End-to-End Validation
Use the manual workflow `.github/workflows/manual-e2e-validate.yml` to validate this action against the centralized E2E repository.

- `mode=image` validates a published image tag (recommended for `-test` and `-rc` release checks).
- `mode=ref` validates ref-oriented E2E paths against stable pinned action refs.

CI/CD automation also runs these E2E checks automatically:

- Pull requests: E2E validation runs through reusable org workflows.
- Release branch prepare: E2E validation runs against release candidate artifacts (`-rc`).
- Release create: E2E validation runs against production release artifacts.

Example trigger inputs:

```text
mode=ref
```

```text
mode=image
image_tag=v1.2.3-test
```
