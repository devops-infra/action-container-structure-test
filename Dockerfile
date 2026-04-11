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
  curl -fsSL \
    "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${CST_VERSION}/container-structure-test-linux-${TARGETARCH}" \
    -o /usr/local/bin/container-structure-test ;\
  chmod +x /usr/local/bin/container-structure-test ;\
  container-structure-test version

# Finish up
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
