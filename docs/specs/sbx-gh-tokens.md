# Sandbox GitHub tokens and sandbox pruning

## Problem Statement

A sandbox needs GitHub access so that its agent can push a branch, open a PR, update issues, and read Actions logs. Today, the only easy way to give it access is `sbx secret set github -t "$(gh auth token)"`. That token is an OAuth token with the `repo` scope, so one sandbox can reach every repository I can reach. A fine-grained personal access token is narrower, but GitHub has no API to create one. The pre-fill URL fills in the form, but I must still select the repositories and click **Generate** in a browser, for each token, and again when it expires. `sbx-up` recreates the sandbox on every start, so this work by hand does not scale.

Also, old sandboxes collect. I often run `sbx rm` by hand for many old sandboxes, one per branch.

## Solution

A personal GitHub App mints a token for each sandbox. The token is limited to the project's repositories and to a small set of permissions, and it expires after 1 hour. `sbx-up` registers a host helper as the sandbox's `github` secret, and the `sbx` daemon runs the helper again before the token expires. After a one-time setup, I do not click anything. The App's private key never enters the sandbox.

A new `sbx-prune` command removes all stopped sandboxes after one confirmation, and it removes their secrets.

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
14. As the developer, I want `sbx-up` to remove the old sandbox's secret when it removes the old sandbox, so that secrets do not collect.
15. As the developer, I want to run `sbx-token` alone, so that I can register, unregister, or test a token without starting a sandbox.
16. As the developer, I want `doctor` to report whether the App ID is set, whether the key is in the OS secret store, and whether a test token mints, so that I find setup problems before I start a sandbox.
17. As the developer, I want `doctor` to report `pending` when the App is not set up yet, so that a new machine does not show a failure for a step that I have not done.
18. As the developer, I want `doctor` to list sandbox secrets that have no sandbox, so that I know when to clean up.
19. As the developer, I want `sbx-prune` to remove every stopped sandbox in all projects, so that I do not remove old sandboxes one at a time.
20. As the developer, I want `sbx-prune` to show the list and ask once (y/N), so that I do not remove a sandbox by mistake.
21. As the developer, I want `--dry-run` and `--yes` on `sbx-prune`, so that I can see the list without removing anything, or skip the prompt.
22. As the developer, I want `sbx-prune` to remove the secret of each sandbox that it removes and all orphaned sandbox secrets, so that one command cleans up both.
23. As the developer, I want PRs and comments made by a sandbox to show the App as the author, so that I can see which work an agent did.

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
- The helper finds the installation ID for each owner with `GET /users/{owner}/installation`.

### `sbx-token` (new command)

- `sbx-token setup` runs the App Manifest flow. It opens a pre-filled "create App" page with the ceiling permissions, receives the App ID and private key on a local callback, stores the key in the OS secret store, and writes the config. On a second machine, a separate step adds a new key to the same App.
- `sbx-token register <sandbox> [--repo owner/name]… [--perm name=level]…` checks the request against the ceiling, mints one token to fail fast, and then registers the helper as the sandbox's `github` secret.
- `sbx-token unregister <sandbox>` runs `sbx secret rm` for that sandbox. It succeeds when no secret exists.
- `sbx-token mint` is the helper that the `sbx` daemon runs. It prints only the token on stdout.
- `sbx-token check` mints a test token. `doctor` uses it.
- Errors name the cause: no config, no key in the store, App not installed on the owner (with the install URL), a permission above the ceiling, or an API error.
- The mint helper runs from the installed copy in `~/.local/lib`, so the registered `--command` uses an absolute path.

### `sbx-up` changes

- New `.sbx.json` keys: `repos` (a list of `owner/name`, default: the repository of `origin`) and `permissions` (an object that is merged over the default permissions).
- New flag: `--no-gh`.
- Order: `sbx-up` resolves the config, unregisters the old sandbox's secret and removes the old sandbox, registers the new secret, and runs `sbx run`. If registration fails, `sbx-up` stops before it runs the sandbox. The order of register and `sbx run` may change if `sbx` does not accept `--sandbox` for a sandbox that does not exist yet (see Further Notes).
- `sbx-up` calls `sbx-token` as a separate command. It does not source its files.

### `sbx-prune` (new command)

- It removes every sandbox that `sbx` reports as stopped, in all projects, in both workspace modes.
- It prints the list and asks once (y/N). `--dry-run` prints the list and exits. `--yes` skips the prompt.
- For each removed sandbox, it runs `sbx-token unregister`. Then it removes the orphaned sandbox secrets.
- It does not need to map a sandbox to a project or a branch.

### `doctor` changes

- In the dev profiles that install `sbx-up`, `doctor` gets checks for the App config, the key in the OS secret store, and a test mint. It reports `pending` when `sbx-token setup` has not run yet.
- It warns about sandbox secrets that have no sandbox.

### Install and documentation

- `sbx-token` and `sbx-prune` go in `commands/`, and the manifests of the profiles that install `sbx-up` install them too.
- bats-core becomes a package in the dev profiles.
- The bootstrap of `dev-mac` gets a step that runs `sbx-token setup` or adds a key for a new machine.
- The commands README lists the two new commands.

## Testing Decisions

- A good test runs a real entry point and checks what the user sees: the exit status, stdout and stderr, and the calls made to external systems. A test does not source `lib/` files or call internal functions.
- **There is one seam: the command line of each command** (`sbx-token`, `sbx-prune`, `sbx-up`, and the new `doctor` checks). Each test puts a fake directory first on `PATH` with:
  - a fake `sbx` that records its calls (`secret set`, `secret rm`, `secret ls`, `rm`, `run`, `ls`) and reports the sandbox list and their states from a fixture
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
  - unregister and register in `sbx-up`, in the correct order
  - no fallback to `gh auth token`
  - the `sbx-prune` prompt, `--dry-run`, and `--yes`, and that it removes only stopped sandboxes
  - orphan cleanup
  - `pending` and `ok` in `doctor`

## Out of Scope

- The host `gh` keeps its hand-made, issues-only fine-grained PAT.
- Fine-grained PATs and the pre-fill URL. The research rejected them because they cannot be fully automated.
- GitHub App user tokens (tokens that act as me).
- Revoking cached tokens with `DELETE /installation/token`. A token lives for 1 hour at most, and the `sbx` daemon holds the cached copy.
- Bitwarden as a key store. Its CLI needs an unlocked session, and the `sbx` daemon runs the helper in the background.
- Pruning by branch state or by age.
- Repositories whose owner has not installed the App (other people's repositories). These fail with the install URL.

## Further Notes

- The research, with primary-source citations, is in `docs/research/fine-grained-gh-tokens-for-sandboxes.md`.
- Facts to confirm on the host before or during implementation:
  1. Does `git push` work through the `sbx` proxy with an installation token? The docs do not say which auth header the built-in `github` service writes for Git over HTTPS.
  2. Does `sbx secret set --sandbox <name>` accept a name before that sandbox exists? The answer sets the order in `sbx-up`.
  3. Does `sbx ls` show running and stopped states in a form that a script can read? Does a sandbox stop by itself after its processes exit? `sbx-prune` depends on both.
  4. Can a local script capture the App ID and PEM from the Manifest flow? (The flow redirects to a callback URL with a code, and the code is exchanged with `POST /app-manifests/{code}/conversions`.)
  5. Does `sbx secret ls` list secrets for each sandbox? Orphan detection depends on it.
- When the Linux AI workstation profile is set up, its profile gets the same `sbx-token` install and a key of its own.
