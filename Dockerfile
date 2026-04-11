FROM alpine:3.21

# Copy all needed files
COPY entrypoint.sh /

# Install needed packages
# hadolint ignore=DL3018
RUN apk add --no-cache \
      bash \
      curl \
      jq && \
    chmod +x /entrypoint.sh

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# Install container-structure-test binary
ARG TARGETARCH
# renovate: datasource=github-releases depName=GoogleContainerTools/container-structure-test
ARG CST_VERSION=v1.22.1
RUN set -eux ;\
  case "${TARGETARCH}" in amd64|arm64) ;; *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; esac ;\
  binary="container-structure-test-linux-${TARGETARCH}" ;\
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
  rm -f /tmp/checksums.txt ;\
  container-structure-test version

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
