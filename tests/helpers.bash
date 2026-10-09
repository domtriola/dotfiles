# Shared setup for the bats suites. Each test gets its own HOME and a fake
# directory first on PATH, holding the external systems a command talks to:
# sbx, tmux, the GitHub API (as curl), the OS secret stores, and gh.

repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
sbx_token="$repo_root/commands/sbx-token/sbx-token"

common_setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export FAKE_STATE="$BATS_TEST_TMPDIR/state"
  export PATH="$repo_root/tests/fakes/bin:$PATH"
  export SBX_TOKEN_BIN="$sbx_token"
  export SBX_TOKEN_STORE="secret-tool"
  mkdir -p "$HOME" "$FAKE_STATE"
  : >"$FAKE_STATE/curl.log"
  : >"$FAKE_STATE/sbx.log"
}

# A real RSA key for the whole file, so that JWT signing runs for real.
make_key() {
  export FAKE_PEM="$BATS_FILE_TMPDIR/app.pem"
  [[ -f "$FAKE_PEM" ]] || openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$FAKE_PEM" 2>/dev/null
}

# given_app sets this machine up as if sbx-token import-key had run.
given_app() {
  mkdir -p "$XDG_CONFIG_HOME/sbx-token"
  echo '{"app_id": 99, "slug": "me-sbx"}' >"$XDG_CONFIG_HOME/sbx-token/config.json"
  openssl base64 -A <"$FAKE_PEM" >"$FAKE_STATE/store"
}

# requests prints the logged GitHub requests as "METHOD /path".
requests() {
  jq -r '"\(.method) \(.path)"' "$FAKE_STATE/curl.log"
}

# token_request prints the body of the last token request.
token_request() {
  jq -r 'select(.path | endswith("/access_tokens")) | .body' "$FAKE_STATE/curl.log" | tail -1
}

# verify_jwt checks that a JWT is signed by the test key and issued by App 99.
verify_jwt() {
  local jwt="$1" header payload sig
  IFS=. read -r header payload sig <<<"$jwt"
  b64url_decode() {
    local s
    s="$(printf '%s' "$1" | tr '_-' '/+')"
    while ((${#s} % 4)); do s+="="; done
    printf '%s' "$s" | openssl base64 -d -A
  }
  openssl pkey -in "$FAKE_PEM" -pubout -out "$BATS_TEST_TMPDIR/pub.pem" 2>/dev/null
  printf '%s.%s' "$header" "$payload" |
    openssl dgst -sha256 -verify "$BATS_TEST_TMPDIR/pub.pem" -signature <(b64url_decode "$sig") >/dev/null &&
    [[ "$(b64url_decode "$payload" | jq -r .iss)" == "99" ]]
}
