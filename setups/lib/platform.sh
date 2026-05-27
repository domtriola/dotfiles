#!/usr/bin/env bash

is_mac() { [[ "$OSTYPE" == darwin* ]]; }
is_linux() { [[ "$OSTYPE" == linux-gnu* ]]; }
is_fedora() { is_linux && [[ -f /etc/fedora-release ]]; }
is_ubuntu() { is_linux && [[ -f /etc/lsb-release ]] && grep -q Ubuntu /etc/lsb-release; }
