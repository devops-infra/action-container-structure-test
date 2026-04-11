# 🚀 Container Structure Test
**GitHub Action running Google Container Structure Tests against a container image**


## 📦 Available on
- **Docker Hub:** [devopsinfra/container-structure-test:latest](https://hub.docker.com/repository/docker/devopsinfra/container-structure-test)
- **GitHub Packages:** [ghcr.io/devops-infra/container-structure-test:latest](https://github.com/devops-infra/container-structure-test/pkgs/container/container-structure-test)


## ✨ Features
* Runs [GoogleContainerTools/container-structure-test](https://github.com/GoogleContainerTools/container-structure-test) in CI
* Supports all test types: command tests, file existence tests, file content tests, metadata tests, license tests
* Supports `docker`, `tar`, and `host` drivers
* Exposes test totals (total / passed / failed) as Action outputs
* Multi-platform image: `linux/amd64` and `linux/arm64`
* Lightweight Alpine-based Docker image


## 🔗 Related Actions
Check also other actions from [DevOps-Infra](https://shyper.pro/portfolio/projects/actions/)


## 📊 Badges
[
![GitHub repo](https://img.shields.io/badge/GitHub-devops--infra%2Fcontainer--structure--test-blueviolet.svg?style=plastic&logo=github)
![GitHub last commit](https://img.shields.io/github/last-commit/devops-infra/container-structure-test?color=blueviolet&logo=github&style=plastic&label=Last%20commit)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/devops-infra/container-structure-test?color=blueviolet&label=Code%20size&style=plastic&logo=github)
![GitHub license](https://img.shields.io/github/license/devops-infra/container-structure-test?color=blueviolet&logo=github&style=plastic&label=License)
](https://github.com/devops-infra/container-structure-test "shields.io")
<br>
[
![DockerHub](https://img.shields.io/badge/DockerHub-devopsinfra%2Fcontainer--structure--test-blue.svg?style=plastic&logo=docker)
![Docker version](https://img.shields.io/docker/v/devopsinfra/container-structure-test?color=blue&label=Version&logo=docker&style=plastic&sort=semver)
![Image size](https://img.shields.io/docker/image-size/devopsinfra/container-structure-test/latest?label=Image%20size&style=plastic&logo=docker)
![Docker Pulls](https://img.shields.io/docker/pulls/devopsinfra/container-structure-test?color=blue&label=Pulls&logo=docker&style=plastic)
](https://hub.docker.com/r/devopsinfra/container-structure-test "shields.io")


## 🏷️ Version Tags: vX, vX.Y, vX.Y.Z
This action supports three tag levels for flexible versioning:
- `vX`: latest patch of the major version (e.g., `v1`).
- `vX.Y`: latest patch of the minor version (e.g., `v1.0`).
- `vX.Y.Z`: fixed to a specific release (e.g., `v1.0.0`).


## 📖 API Reference
```yaml
    - name: Run the Action
      uses: devops-infra/container-structure-test@v1.0.0
      with:
        image: my-image:latest
        config: tests/structure-test.yaml
        driver: docker
        output: text
        debug: false
```

### 🔧 Input Parameters
| Input                   | Required | Default  | Description                                                                                   |
|:------------------------|:--------:|:--------:|:----------------------------------------------------------------------------------------------|
| `image`                 |    *     |          | Image to test. Required unless `image_from_oci_layout` is set. Mutually exclusive with it.   |
| `config`                |   Yes    |          | Path(s) to test config file(s). Space or newline-separated for multiple files.               |
| `driver`                |    No    | `docker` | Driver to use when running tests: `docker`, `tar`, or `host`.                                 |
| `platform`              |    No    |          | Platform to test, e.g. `linux/amd64` or `linux/arm64`. Defaults to host arch.                |
| `pull`                  |    No    | `false`  | Force pull the image before running tests (docker driver only).                               |
| `save`                  |    No    | `false`  | Preserve created containers after the test run.                                               |
| `quiet`                 |    No    | `false`  | Suppress test output.                                                                         |
| `no_color`              |    No    | `false`  | Disable colorized output.                                                                     |
| `output`                |    No    | `text`   | Output format: `text`, `json`, or `junit`.                                                    |
| `test_report`           |    No    |          | Write test results to this file path. CST converts `text` to `json` automatically.           |
| `junit_suite_name`      |    No    |          | Name for the JUnit test suite (only used when `output` is `junit`).                           |
| `metadata`              |    No    |          | Path to image metadata file.                                                                  |
| `runtime`               |    No    |          | Runtime to use with the docker driver (e.g. `runsc` for gVisor).                             |
| `force`                 |    No    | `false`  | Force run of host driver without interactive prompt.                                          |
| `image_from_oci_layout` |    No    |          | Path to OCI image layout directory. Mutually exclusive with `image`.                          |
| `default_image_tag`     |    No    |          | Default image tag when OCI layout lacks a ref annotation. Requires `image_from_oci_layout`.  |
| `ignore_ref_annotation` |    No    | `false`  | Ignore `org.opencontainers.image.ref.name` annotation when loading OCI layout.               |
| `debug`                 |    No    | `false`  | Enable verbose debug logging in the action entrypoint.                                        |


### 📤 Output Parameters
| Output      | Description                                          |
|:------------|:-----------------------------------------------------|
| `total`     | Total number of tests executed.                      |
| `passed`    | Number of tests that passed.                         |
| `failed`    | Number of tests that failed.                         |
| `exit_code` | Exit code returned by `container-structure-test`.    |


## 💻 Usage Examples

### 📝 Basic
Run structure tests against a Docker image using a single config file.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Build image
        run: docker build -t my-image:latest .

      - uses: devops-infra/container-structure-test@v1
        with:
          image: my-image:latest
          config: tests/structure-test.yaml
```

### 🔀 Advanced
Run tests with multiple config files, JSON output, and a saved report.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Build image
        run: docker build -t my-image:latest .

      - name: Run structure tests
        id: cst
        uses: devops-infra/container-structure-test@v1
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
Run the action pinned to a specific version tag.

```yaml
name: Run structure tests on each commit
on: [push]
jobs:
  container-structure-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: devops-infra/container-structure-test@v1.0.0
        id: Pin patch version
        with:
          image: my-image:latest
          config: tests/structure-test.yaml

      - uses: devops-infra/container-structure-test@v1.0
        id: Pin minor version
        with:
          image: my-image:latest
          config: tests/structure-test.yaml

      - uses: devops-infra/container-structure-test@v1
        id: Pin major version
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
      - uses: actions/checkout@v5

      - name: Build image
        run: docker build -t my-image:latest .

      - name: Run structure tests
        uses: devops-infra/container-structure-test@v1
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
      - uses: actions/checkout@v5

      - name: Export image as tar
        run: docker save my-image:latest -o my-image.tar

      - uses: devops-infra/container-structure-test@v1
        with:
          image: my-image.tar
          config: tests/file-tests.yaml
          driver: tar
```


## 📋 Test Config Reference

Container Structure Test configs are YAML or JSON files.
The current schema version is `2.0.0` and must be set in every config.

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
- (Auto) Create Pull Request (`.github/workflows/auto-create-pull-request.yml`)
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
- (Cron) Weekly dependency build (`.github/workflows/cron-check-dependencies.yml`)
  - Trigger: Weekly on Monday at 08:00 UTC
  - Jobs:
    - Lint
    - Build and push multi-platform test image, and inspect manifest
- (Manual) Update version (`.github/workflows/manual-update-version.yml`)
  - Trigger: manual `workflow_dispatch` with `type` (`patch|minor|major|set`) xor `version` when `type=set`
pushes to `release/**` branch and creates a pull request to create a new release
  - Jobs:
    - Update version: bump or set; output `REL_VERSION`
    - Build and push multi-platform image, and inspect manifest
    - Create pull request, approve to create a release


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

# Push images (requires DOCKER_TOKEN and GITHUB_TOKEN)
DOCKER_TOKEN=... GITHUB_TOKEN=... task docker:push
```

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
- 📝 Create an [issue](https://github.com/devops-infra/container-structure-test/issues)
- 🌟 Star this repository if you find it useful!
