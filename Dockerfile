FROM alpine:3.23.3

# Multi-architecture from buildx
ARG TARGETARCH

# GoogleContainerTools/container-structure-test
ARG CST_VERSION=v1.22.1

# Copy all needed files
COPY entrypoint.sh /
COPY alpine-packages.txt /tmp/alpine-packages.txt

# Install needed packages
SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]
# hadolint ignore=DL3018
RUN set -eux; \
  xargs -r apk add --no-cache < /tmp/alpine-packages.txt; \
  chmod +x /entrypoint.sh; \
  targetarch="${TARGETARCH:-}" ;\
  if [ -z "${targetarch}" ]; then \
    case "$(uname -m)" in \
      x86_64) targetarch="amd64" ;; \
      aarch64|arm64) targetarch="arm64" ;; \
      *) echo "Unsupported host architecture: $(uname -m)"; exit 1 ;; \
    esac ;\
  fi ;\
  case "${targetarch}" in amd64|arm64) ;; *) echo "Unsupported TARGETARCH: ${targetarch}"; exit 1 ;; esac ;\
  binary="container-structure-test-linux-${targetarch}" ;\
  base_url="https://github.com/GoogleContainerTools/container-structure-test/releases/download/${CST_VERSION}" ;\
  curl -fsSL "${base_url}/checksums.txt" -o /tmp/checksums.txt ;\
  curl -fsSL \
    "${base_url}/${binary}" \
    -o /usr/local/bin/container-structure-test ;\
  expected_sha="$(awk -v b="${binary}" '$2==b {print $1}' /tmp/checksums.txt)" ;\
  [ -n "${expected_sha}" ] ;\
  actual_sha="$(sha256sum /usr/local/bin/container-structure-test | awk '{print $1}')" ;\
  [ "${actual_sha}" = "${expected_sha}" ] ;\
  chmod +x /usr/local/bin/container-structure-test ;\
  rm -rf /var/cache/* ;\
  rm -rf /root/.cache/* ;\
  rm -rf /tmp/* ;\
  container-structure-test version

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
