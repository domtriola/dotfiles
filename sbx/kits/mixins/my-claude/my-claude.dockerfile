# syntax=docker/dockerfile:1

# The overlay for the my-claude mixin. See my-claude.yaml for why every file
# is outside /home/agent.
#
# A build stage stages the whole tree in /out, and the overlay copies it as is.
# An overlay's directory entries replace the workload's, so every directory
# must be root's with mode 0755. A `COPY --chmod` straight into the overlay
# gives the parent directories that it creates the file's mode, which would
# make /etc unreadable as a directory.
#
# gh is a pinned release from GitHub. The workload ships a gh from its own
# package set, which moves when the workload does. /usr/local/bin comes before
# /usr/bin on PATH. The checksum file comes from the same release, which is
# safe because cli/cli releases are immutable. Renovate bumps GH_VERSION (see
# renovate.json at the repository root) and the Alpine tag and digest.
FROM alpine:3.23@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2 AS build
ARG TARGETARCH
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.103.3
WORKDIR /tmp/gh
RUN set -eu; \
    tarball="gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    url="https://github.com/cli/cli/releases/download/v${GH_VERSION}"; \
    wget -q "$url/$tarball" "$url/gh_${GH_VERSION}_checksums.txt"; \
    grep " $tarball\$" "gh_${GH_VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "$tarball"; \
    install -D -m 0755 gh_*/bin/gh /out/usr/local/bin/gh

COPY files/ /tmp/files/
RUN set -eu; \
    install -D -m 0644 /tmp/files/settings.json /out/etc/claude-code/managed-settings.json; \
    install -D -m 0644 /tmp/files/CLAUDE.md /out/etc/claude-code/CLAUDE.md; \
    install -D -m 0755 /tmp/files/statusline.sh /out/usr/local/libexec/my-claude/statusline.sh; \
    find /out -type d -exec chmod 0755 {} +

FROM scratch
COPY --from=build /out/ /
