# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# The overlay for the playwright-cli mixin: the install script that its
# startup hook runs. Outside /home/agent, because the parent directories that
# COPY creates are owned by root.
FROM scratch
COPY --chmod=0755 files/install /usr/local/libexec/playwright-cli-kit/install
