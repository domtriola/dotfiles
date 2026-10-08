# Sandbox GitHub tokens

## Problem Statement

A sandbox needs GitHub access so that its agent can push a branch, open a PR, update issues, and read Actions logs. Today, the only easy way to give it access is `sbx secret set github -t "$(gh auth token)"`. That token is an OAuth token with the `repo` scope, so one sandbox can reach every repository I can reach. A fine-grained personal access token is narrower, but GitHub has no API to create one. The pre-fill URL fills in the form, but I must still select the repositories and click **Generate** in a browser, for each token, and again when it expires. `sbx-up` recreates the sandbox on every start, so this work by hand does not scale.

Also, old sandboxes collect. I often run `sbx rm` by hand for many old sandboxes, one per branch.

## Solution

A personal GitHub App mints a token for each sandbox. The token is limited to the project's repositories and to a small set of permissions, and it expires after 1 hour. `sbx-up` registers a host helper as the sandbox's `github` secret, and the `sbx` daemon runs the helper again before the token expires. After a one-time setup, I do not click anything. The App's private key never enters the sandbox.

For old sandboxes, `sbx prune` already removes all stopped sandboxes after one confirmation, and it deletes their secrets. This spec adds no command for it.

## User Stories

1. As the developer, I want each sandbox to get a GitHub token limited to its project's repository, so that a leaked token cannot reach my other repositories.
2. As the developer, I want the default token to allow contents write, pull requests write, issues write, and actions read, so that the usual agent flow (push, open a PR, update issues, read CI logs) works without configuration.
3. As the developer, I want to list extra repositories in a project's `.sbx.json`, so that a sandbox can work across related repositories when I ask for it.
4. As the developer, I want to change the permissions in a project's `.sbx.json`, so that a project can get more access (for example, `workflows: write`) or less.
5. As the developer, I want a permission request above the App's ceiling to fail with a clear error, so that I know why the token was not minted.
6. As the developer, I want sandbox tokens to refresh on their own while the sandbox runs, so that a long session does not lose GitHub access after 1 hour.
7. As the developer, I want to create the GitHub App with one click from a pre-filled page, so that the setup does not need me to copy settings or keys by hand.
8. As the developer, I want each machine to have its own App private key, so that I can revoke the key of a lost machine and keep the other machines working.
9. As the developer, I want the private key in the OS secret store (the Keychain on macOS and Secret Service on Linux), so that the same design works on my Mac and on my future Linux workstation.
10. As the developer, I want `sbx-up` to mint one token before it starts the sandbox, so that a missing key, an App that is not installed, or a network failure stops the start with a clear error.
11. As the developer, I want the error to include the App's install URL when the App is not installed on the repository's owner, so that I can fix it in one step.
12. As the developer, I want a `--no-gh` flag on `sbx-up`, so that I can start a sandbox without GitHub access when I want to.
13. As the developer, I want `sbx-up` never to fall back to a broader token, so that a failure cannot remove the limits without my knowledge.
14. As the developer, I want the secret of a sandbox to go away with the sandbox, so that secrets do not collect. (`sbx rm` and `sbx prune` already do this.)
15. As the developer, I want to run `sbx-token` alone, so that I can register or test a token without starting a sandbox.
16. As the developer, I want `doctor` to report whether the App ID is set, whether the key is in the OS secret store, and whether a test token mints, so that I find setup problems before I start a sandbox.
17. As the developer, I want `doctor` to report `pending` when the App is not set up yet, so that a new machine does not show a failure for a step that I have not done.
18. As the developer, I want `doctor` to warn me about a global `github` secret, so that I know when a sandbox without its own token still gets a broad one.
19. As the developer, I want PRs and comments made by a sandbox to show the App as the author, so that I can see which work an agent did.

## Implementation Decisions

### Token mechanism

- A personal GitHub App, installed on all of my repositories. Each token is limited in the helper, not by the installation.
- The App's permission ceiling is contents (write), pull requests (write), issues (write), actions (read), metadata (read), and workflows (write).
- The tokens are installation access tokens from `POST /app/installations/{id}/access_tokens`, with `repositories` and `permissions` in the request body. They expire after 1 hour.
- The registration uses `sbx secret set github --sandbox <name> --command '<helper> …'`. The `sbx` daemon caches the output for 55 minutes by default, which is shorter than the life of the token, so the design needs no rotation code.
- The helper is Bash with `openssl` (RS256 JWT), `curl`, and `jq`, which matches the other commands.

### Storage

- The private key is stored in the OS secret store, behind a small backend layer: `security` on macOS and `secret-tool` on Linux. These are the same stores that `sbx` uses.
- Each machine has its own key. The App can hold more than one key.
- The App ID and the App slug (for the install URL) are not secret. They go in a config file under `~/.config/sbx-token/`.
- The helper finds the installation ID with `GET /repos/{owner}/{repo}/installation`, for the first repository. All the repositories of one token must have one owner, because a token belongs to one installation.

### `sbx-token` (new command)

- `sbx-token setup` runs the App Manifest flow. It opens a local page that posts the manifest (with the ceiling permissions) to GitHub. GitHub redirects to `http://127.0.0.1:1/`, where nothing listens, so the one-hour code stays on this machine, and I paste the address back. The command exchanges the code for the App ID and private key, stores the key in the OS secret store, and writes the config. On a second machine, a separate step adds a new key to the same App.
- `sbx-token register <sandbox> [--repo owner/name]… [--perm name=level]…` checks the request against the ceiling, mints one token to fail fast, and then registers the helper as the sandbox's `github` secret. There is no `unregister`, because `sbx rm` deletes the secrets of each sandbox that it removes.
- `sbx-token mint` is the helper that the `sbx` daemon runs. It prints only the token on stdout. It runs under macOS `/bin/bash` 3.2 with a minimal PATH, so the command needs no bash 4.
- `sbx-token check` authenticates as the App and lists its installations. `doctor` uses it. `--offline` only checks that the config and the key are on this machine.
- `sbx-token import-key --app-id <id> <pem>` stores a key for an App that already exists, and reads the slug from GitHub.
- Errors name the cause: no config, no key in the store, App not installed on the owner (with the install URL), a permission above the ceiling, or an API error.
- The mint helper runs from the installed copy in `~/.local/lib`, so the registered `--command` uses an absolute path.

### `sbx-up` changes

- New `.sbx.json` keys: `repos` (a list of `owner/name`, default: the repository of `origin`) and `permissions` (an object that is merged over the default permissions).
- New flag: `--no-gh`.
- Order: `sbx-up` resolves the config, mints one token (and stops if it cannot, before anything is removed), removes the old sandbox, registers the new secret, and runs `sbx run`. The secret is registered after the removal, because `sbx rm` deletes it. The order of register and `sbx run` may change if `sbx` does not accept `--sandbox` for a sandbox that does not exist yet (see Further Notes).
- `sbx-up` calls `sbx-token` as a separate command. It does not source its files.

### `doctor` changes

- In the dev-mac profile (the only dev profile with doctor checks), `doctor` runs `sbx-token check`. It reports `pending` when `sbx-token setup` has not run yet, and passes `--offline` when `doctor` runs offline.
- It warns about a global `github` secret. A sandbox-scoped secret overrides a global one, so a global secret reaches every sandbox that has no token of its own (`sbx-up --no-gh`, and plain `sbx run`).

### Install and documentation

- `sbx-token` goes in `commands/`, and the manifests of the profiles that install `sbx-up` install them too.
- bats-core becomes a package in the dev profiles.
- The bootstrap of `dev-mac` gets a step that runs `sbx-token setup` or adds a key for a new machine.
- The commands README lists the new command and says how to run the tests.

## Testing Decisions

- A good test runs a real entry point and checks what the user sees: the exit status, stdout and stderr, and the calls made to external systems. A test does not source `lib/` files or call internal functions.
- **There is one seam: the command line of each command** (`sbx-token` and `sbx-up`). Each test puts a fake directory first on `PATH` with:
  - a fake `sbx` that records its calls, keeps the secrets that `secret set` stores, and runs a `--command` once, as `sbx` does when it stores one
  - a fake OS secret store (`security` and `secret-tool`) that serves a test PEM, or fails when the PEM is missing
  - a fake `curl` that returns fixed GitHub API responses, including the "not installed" case and API errors, and records the request bodies, so that tests can check the requested `repositories` and `permissions`
- `openssl` and `jq` stay real, so JWT signing runs against a test key.
- The runner is bats-core.
- There is no prior art. This is the first test suite in the repository, so it sets the pattern for later suites.
- What to cover:
  - the default limits on the token, and the overrides from `.sbx.json`
  - the ceiling check
  - `--no-gh`
  - the fail-fast errors and the install URL
  - mint, remove, and register in `sbx-up`, in the correct order
  - no fallback to `gh auth token`
  - the setup manifest, the state check, and import-key
- The suite also passes under bash 3.2 (the `bash:3.2` image), because the `sbx` daemon may run the helper with macOS `/bin/bash`.

## Out of Scope

- The host `gh` keeps its hand-made, issues-only fine-grained PAT.
- Fine-grained PATs and the pre-fill URL. The research rejected them because they cannot be fully automated.
- GitHub App user tokens (tokens that act as me).
- Revoking cached tokens with `DELETE /installation/token`. A token lives for 1 hour at most, and the `sbx` daemon holds the cached copy.
- Bitwarden as a key store. Its CLI needs an unlocked session, and the `sbx` daemon runs the helper in the background.
- A `sbx-prune` command. `sbx prune` already removes stopped sandboxes and their secrets.
- `doctor` checks for orphaned sandbox secrets. `sbx rm` and `sbx prune` delete them.
- Repositories whose owner has not installed the App (other people's repositories). These fail with the install URL.

## Further Notes

- The research, with primary-source citations, is in `docs/research/fine-grained-gh-tokens-for-sandboxes.md`.
- Facts to confirm on the host before or during implementation:
  1. Does `git push` work through the `sbx` proxy with an installation token? The docs do not say which auth header the built-in `github` service writes for Git over HTTPS.
  2. Does `sbx secret set --sandbox <name>` accept a name before that sandbox exists? The answer sets the order in `sbx-up`.
  3. Does a sandbox stop by itself after its agent exits, so that `sbx prune` finds it?
  4. Does GitHub accept the manifest from a local page, and redirect to the unreachable `127.0.0.1:1` address so that the code can be pasted back?
  5. Can the `sbx` daemon run the helper and read the Keychain? `sbx secret set --command` runs the helper once, so `register` reports this.
- When the Linux AI workstation profile is set up, its profile gets the same `sbx-token` install and a key of its own.
