#!/bin/sh
#
# Point npm at the sandbox proxy.
#
# pi reaches npm at run time as well as at build time: extensions, skills,
# prompt templates and themes are fetched on startup, and `pi install npm:...`
# and `pi update` run later. Those happen in exec contexts that do not inherit
# the proxy environment, so the setting has to be in ~/.npmrc rather than in
# the environment.
#
# pi itself is baked into the image, so nothing is installed here.
#
# Guarded on HTTP_PROXY being non-empty: npm rejects an empty value for a
# url-typed config key, and a failure here takes sandbox creation down with it.
# A proxy-less runtime is something every sibling kit tolerates.
#
# HTTPS_PROXY is preferred for https-proxy when the runtime provides a
# dedicated one, with HTTP_PROXY as the fallback. Both keys go in one call, so
# sandbox creation pays for one Node startup rather than two.

set -eu

[ -n "${HTTP_PROXY:-}" ] || exit 0

npm config set proxy="$HTTP_PROXY" https-proxy="${HTTPS_PROXY:-$HTTP_PROXY}"
