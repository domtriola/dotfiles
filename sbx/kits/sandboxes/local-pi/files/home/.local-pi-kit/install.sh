#!/bin/sh
#
# Point npm at the sandbox proxy.
#
# pi fetches packages at run time, in exec contexts that do not inherit the
# proxy environment, so the setting has to be in ~/.npmrc.
#
# Guarded on HTTP_PROXY being non-empty: npm rejects an empty value for a
# url-typed config key, and a failure here takes sandbox creation down with it.

set -eu

[ -n "${HTTP_PROXY:-}" ] || exit 0

npm config set proxy="$HTTP_PROXY" https-proxy="${HTTPS_PROXY:-$HTTP_PROXY}"
