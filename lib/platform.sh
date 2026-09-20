#!/usr/bin/env bash

is_mac() { [[ "$OSTYPE" == darwin* ]]; }
is_linux() { [[ "$OSTYPE" == linux-gnu* ]]; }
is_fedora() { is_linux && [[ -f /etc/fedora-release ]]; }
is_ubuntu() { is_linux && [[ -f /etc/lsb-release ]] && grep -q Ubuntu /etc/lsb-release; }
is_qubes() { is_linux && uname -r | grep -qi qubes; }

# A Docker Sandbox always sets SANDBOX_NAME and always has the persistent
# environment file. /run/sandbox is not a marker: it exists only in clone mode.
is_sandbox() {
  is_linux && { [[ -n "${SANDBOX_NAME:-}" ]] || [[ -f /etc/sandbox-persistent.sh ]]; }
}
