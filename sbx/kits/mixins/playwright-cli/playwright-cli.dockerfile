# syntax=docker/dockerfile:1

# The overlay for the playwright-cli mixin: the install script that its
# startup hook runs. Outside /home/agent, because the parent directories that
# COPY creates are owned by root.
FROM scratch
COPY --chmod=0755 files/install /usr/local/libexec/playwright-cli-kit/install
