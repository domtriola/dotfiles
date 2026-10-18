#!/usr/bin/env bats
#
# The playwright-cli kit's install script, which the startup hook runs in the
# background. The Node mirror is a directory of fake releases, read with the
# real curl through file:// URLs. Each fake release holds an npm that installs
# a fake playwright-cli, which logs its calls, and fails when
# FAKE_PLAYWRIGHT_CLI_FAIL is set.

load helpers

setup() {
  common_setup
  install="$repo_root/sbx/kits/mixins/playwright-cli/files/home/.local/libexec/playwright-cli-kit/install"
  status_file="$HOME/.playwright-cli-kit.status"
  log="$HOME/.playwright-cli-kit.log"
  workspace="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$workspace"
  : >"$FAKE_STATE/npm.log"
  : >"$FAKE_STATE/playwright-cli.log"

  # The fake curl answers only like the GitHub API, so this file uses the real
  # one, ahead of the fakes on PATH.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  ln -s "$(PATH="${PATH#*/tests/fakes/bin:}" command -v curl)" "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  export PLAYWRIGHT_CLI_KIT_NODE_MIRROR="file://$BATS_FILE_TMPDIR/dist"
  [[ -d "$BATS_FILE_TMPDIR/dist" ]] || make_mirror
}

# make_mirror writes a Node mirror with these releases, newest first. Only the
# ones with a codename are LTS.
make_mirror() {
  local dist="$BATS_FILE_TMPDIR/dist" arch
  case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  esac
  mkdir -p "$dist"
  printf 'version\tdate\tfiles\tnpm\tv8\tuv\tzlib\topenssl\tmodules\tlts\tsecurity\n' >"$dist/index.tab"
  while read -r version lts; do
    printf '%s\t2026-01-01\tlinux-x64,linux-arm64\t-\t-\t-\t-\t-\t-\t%s\t-\n' "$version" "$lts" >>"$dist/index.tab"
    make_release "$dist" "$version" "$arch"
  done <<'EOF'
v26.12.0 -
v24.11.0 Krypton
v24.10.0 Krypton
v22.21.0 Jod
v20.19.0 Iron
v20.18.0 Iron
EOF
}

# make_release writes one release tarball and its checksum file. Its node
# prints the version, and its npm logs its arguments and installs a fake
# playwright-cli into the --prefix it is given.
make_release() {
  local dist="$1" version="$2" arch="$3" name
  name="node-$version-linux-$arch"
  local root="$BATS_FILE_TMPDIR/build/$name"
  mkdir -p "$root/bin" "$dist/$version"
  printf '#!/bin/sh\necho %s\n' "$version" >"$root/bin/node"
  cat >"$root/bin/npm" <<'NPM'
#!/bin/sh
echo "$*" >>"$FAKE_STATE/npm.log"
prefix=""
while [ $# -gt 0 ]; do
  [ "$1" = --prefix ] && prefix="$2"
  shift
done
mkdir -p "$prefix/bin"
cat >"$prefix/bin/playwright-cli" <<'CLI'
#!/bin/sh
echo "PLAYWRIGHT_MCP_BROWSER=$PLAYWRIGHT_MCP_BROWSER node=$(node --version) $*" >>"$FAKE_STATE/playwright-cli.log"
[ -z "${FAKE_PLAYWRIGHT_CLI_FAIL:-}" ] || { echo "Failed to install browsers" >&2; exit 1; }
CLI
chmod +x "$prefix/bin/playwright-cli"
NPM
  chmod +x "$root/bin/node" "$root/bin/npm"
  tar -czf "$dist/$version/$name.tar.gz" -C "$BATS_FILE_TMPDIR/build" "$name"
  (cd "$dist/$version" && sha256sum "$name.tar.gz" >SHASUMS256.txt)
}

# run_install runs the script the way the startup hook does: the status file
# already names the first step, and the output goes to the log.
run_install() {
  echo "starting the playwright-cli kit" >"$status_file"
  run sh -c 'sh "$1" "$2" >>"$3" 2>&1' sh "$install" "$workspace" "$log"
}

@test "a cold install puts playwright-cli on PATH, with the newest LTS Node and Chromium only" {
  run_install
  [ "$status" -eq 0 ]
  [ "$(cat "$status_file")" = "ready" ]
  [ "$(cat "$FAKE_STATE/playwright-cli.log")" = "PLAYWRIGHT_MCP_BROWSER=chromium node=v24.11.0 install-browser chromium --with-deps --no-shell" ]

  : >"$FAKE_STATE/playwright-cli.log"
  run "$HOME/.local/bin/playwright-cli" open http://localhost:8080
  [ "$(cat "$FAKE_STATE/playwright-cli.log")" = "PLAYWRIGHT_MCP_BROWSER=chromium node=v24.11.0 open http://localhost:8080" ]
}

@test "the install does not touch the workspace's dependencies" {
  echo '{"name": "app"}' >"$workspace/package.json"
  run_install
  [ "$(cat "$status_file")" = "ready" ]
  [ "$(cat "$FAKE_STATE/npm.log")" = "install -g --prefix $HOME/.local/share/playwright-cli-kit/node @playwright/cli@latest" ]
  [ "$(ls "$workspace")" = "package.json" ]
}

# installed_node prints the version of the Node that the kit installed.
installed_node() {
  "$HOME/.local/share/playwright-cli-kit/node/bin/node" --version
}

@test "a major version in .nvmrc gets the newest release of that major" {
  echo 20 >"$workspace/.nvmrc"
  run_install
  [ "$(cat "$status_file")" = "ready" ]
  [ "$(installed_node)" = "v20.19.0" ]
}

@test "an exact version in .node-version gets that version" {
  echo v20.18.0 >"$workspace/.node-version"
  run_install
  [ "$(installed_node)" = "v20.18.0" ]
}

@test "an LTS codename in .nvmrc gets the newest release of that line" {
  echo lts/iron >"$workspace/.nvmrc"
  run_install
  [ "$(installed_node)" = "v20.19.0" ]
}

@test "a caret range in engines gets the newest release of its major" {
  printf '{\n  "name": "app",\n  "engines": {\n    "node": "^22.1.0"\n  }\n}\n' >"$workspace/package.json"
  run_install
  [ "$(installed_node)" = "v22.21.0" ]
}

@test "a lower bound in engines gets the newest LTS" {
  echo '{"name": "app", "engines": {"node": ">=20"}}' >"$workspace/package.json"
  run_install
  [ "$(installed_node)" = "v24.11.0" ]
}

@test ".nvmrc wins over engines" {
  echo 22 >"$workspace/.nvmrc"
  echo '{"engines": {"node": ">=20"}}' >"$workspace/package.json"
  run_install
  [ "$(installed_node)" = "v22.21.0" ]
}

@test "a version that no release matches leaves failed, and the reason in the log" {
  echo 19 >"$workspace/.nvmrc"
  run_install
  [ "$(cat "$status_file")" = "failed" ]
  grep -q 'no Node release matches "19"' "$log"
  [ ! -e "$HOME/.local/bin/playwright-cli" ]
}

@test "a download whose checksum does not match leaves failed" {
  export PLAYWRIGHT_CLI_KIT_NODE_MIRROR="file://$BATS_TEST_TMPDIR/dist"
  cp -R "$BATS_FILE_TMPDIR/dist" "$BATS_TEST_TMPDIR/dist"
  sed -i.bak 's/^[0-9a-f]*/0000/' "$BATS_TEST_TMPDIR/dist/v24.11.0/SHASUMS256.txt"
  run_install
  [ "$(cat "$status_file")" = "failed" ]
  grep -q 'the checksum of node-v24.11.0-linux-.*.tar.gz does not match' "$log"
}

@test "a failed browser install leaves failed, and no playwright-cli on PATH" {
  export FAKE_PLAYWRIGHT_CLI_FAIL=1
  run_install
  [ "$(cat "$status_file")" = "failed" ]
  grep -q 'playwright-cli kit failed' "$log"
  [ ! -e "$HOME/.local/bin/playwright-cli" ]
}
