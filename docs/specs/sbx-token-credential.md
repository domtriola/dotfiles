# Choose what holds the credential behind sandbox GitHub tokens

## Problem Statement

`sbx-token` gives each sandbox a GitHub token that reaches only its project's repositories. The tokens come from a personal GitHub App, and the App's private key is in the macOS Keychain. The Keychain item was created by `security`, so any process that runs as me can read the key without a prompt. A process that reads the key can mint tokens for every repository where the App is installed, with every permission that the App holds, from any machine, until I delete the key pair on GitHub.

I want to decide how to keep that credential, before I depend on it on more machines. There are three options:

1. Keep the App key in the Keychain (what is built now).
2. Move the App key to a YubiKey, so that it cannot be copied off the machine.
3. Do not use an App, and give each repository a fine-grained personal access token (PAT) instead.

Each option changes what I must do by hand, what a stolen credential can do, and who GitHub shows as the author of a sandbox's PRs.

## Solution

I choose one option from the comparison below. All three options are behind the same interface: `sbx-up` registers `sbx-token mint --repo … --perm …` as the sandbox's `github` secret, and the `sbx` daemon runs it. So the choice changes only `sbx-token`, its bootstrap steps, and its `doctor` check, and `sbx-up` does not change.

| | A. App key in Keychain (now) | B. App key on YubiKey | C. Fine-grained PAT for each repository |
| --- | --- | --- | --- |
| **One-time setup** | Create the App by hand, and import a key on each machine. | The same as A, then import the key into a PIV slot, and delete the file. | None. |
| **For each new repository** | Nothing. | Nothing. | Open a pre-filled page, select the repository, click **Generate**, and paste the token. |
| **Recurring work** | None. | Keep the YubiKey plugged in. | Make each token again before it expires (at most every 366 days, and 90 days is recommended). |
| **Token that a sandbox holds** | Expires after 1 hour, and is renewed without me. | The same as A. | Lives until the PAT expires (weeks or months). |
| **A sandbox leaks its token** | The leak is good for at most 1 hour, for that sandbox's repositories. | The same as A. | The leak is good until the PAT expires or I delete it, for that repository. |
| **A process that runs as me reads the stored credential** | It can mint tokens for every installed repository, from anywhere, until I delete the key pair. | It can mint tokens only on this machine, and only while the YubiKey is plugged in. It cannot copy the key. | It gets the PATs, each limited to one repository, until each one expires. |
| **The disk or a backup leaks** | Keychain encryption protects the key. | The key is not on the disk. | Keychain encryption protects the PATs. |
| **Author of PRs and comments from a sandbox** | `<login>-sbx[bot]` | `<login>-sbx[bot]` | Me |
| **Revoke** | Delete the machine's key pair under **Credentials**. | Delete the YubiKey's key pair. | Delete each PAT in **Settings**. |
| **Limits** | Repositories must be where the App is installed. | The same as A, plus one YubiKey for the key. | 50 fine-grained PATs per account. One owner for each token. An organization can require approval. A PAT cannot reach repositories where I am an outside collaborator. |
| **Cost** | None. | A YubiKey 5, plus the PIN kept in the Keychain. | Time spent by hand. |

**My recommendation:** keep A now, and move to B when I have a YubiKey. The threat most specific to sandboxes is an agent that leaks its own token (for example, after a prompt injection). A and B limit that leak to 1 hour, but C gives the leaked token weeks or months. B also removes the worst case of A, a key that is copied off the machine. Choose C only if PRs must show me as the author, or if keeping an App costs more than making tokens by hand for my few repositories.

## User Stories

### All options

1. As the developer, I want `sbx-up` to work the same way whichever option I choose, so that the choice does not change how I start sandboxes.
2. As the developer, I want the option that a machine uses to show in `sbx-token check` and in `doctor`, so that I know what protects each machine.
3. As the developer, I want each sandbox token to stay limited to its project's repositories and to the default permissions, so that the choice of option does not widen what a sandbox can reach.
4. As the developer, I want bootstrap steps for the option that I choose, so that I can set up a new machine without reading the code.
5. As the developer, I want an error from the `sbx` daemon to name the cause and the fix, so that a sandbox that loses GitHub access is quick to repair.

### B. App key on a YubiKey

6. As the developer, I want to import the App's private key into a YubiKey PIV slot, so that the key cannot be read back off the device.
7. As the developer, I want the tokens to renew without a touch, so that my sandboxes keep working while I am away from the keyboard.
8. As the developer, I want the PIN to be read from the Keychain and never put on a command line, so that other processes cannot read it with `ps`.
9. As the developer, I want `sbx-token check` to report a YubiKey that is not plugged in, so that I know why the tokens stopped.
10. As the developer, I want `import-key` to tell me to delete the `.pem` file after the import, so that no copy of the key stays on the disk.
11. As the developer, I want one key pair for each YubiKey instead of for each machine, so that I can move the YubiKey between machines.

### C. Fine-grained PATs

12. As the developer, I want `sbx-up` to open a pre-filled token page when a repository has no PAT, so that I only have to select the repository, click **Generate**, and paste the token.
13. As the developer, I want each PAT to be cached in the Keychain by repository, so that every sandbox for that repository uses it without another click.
14. As the developer, I want the pre-filled page to have the name, the owner, the expiry, and the default permissions, so that I cannot give a token too much by mistake.
15. As the developer, I want `sbx-token` to check a pasted PAT with GitHub before it stores it, so that a token for the wrong repository or with the wrong permissions is refused.
16. As the developer, I want `doctor` to warn me some days before a PAT expires, without a call to GitHub, so that a sandbox does not lose access in the middle of a task.
17. As the developer, I want an expired PAT to give an error that names the repository and the fix, so that I know which token to make again.
18. As the developer, I want PRs from a sandbox to show me as the author, so that they look the same as my own PRs.
19. As the developer, I want `sbx-token` to list the cached PATs with their expiry dates, so that I know which ones to delete when I stop using a repository.

## Implementation Decisions

### What stays the same

- `sbx-up` and the command that it registers (`sbx-token mint --repo … --perm …`) do not change.
- `scope` (the repository and permission checks) does not change. For C, it decides which PAT a request needs.
- The default permissions are contents (write), pull requests (write), issues (write), actions (read), and metadata (read).

### A. App key in Keychain

- Already built. No change.

### B. App key on a YubiKey

- **The store becomes a signer.** Today, `app_jwt` reads the PEM from the store and signs with `openssl`. The interface changes to "sign these bytes". The Keychain backend still signs with `openssl`, and the new `yubikey` backend signs on the device. With this change, the key is never in the memory of `sbx-token` for B.
- **Import:** `sbx-token import-key --yubikey --app-id <id> <pem>` imports the key into one PIV slot with the PIN policy "once" and the touch policy "never". It checks the key with GitHub (`GET /app`), saves the App ID, the slug, and the slot, and tells me to delete the file.
- **PIN:** the PIN is stored in the Keychain, and the signer reads it and never puts it on argv.
- **Policies:** "touch never" keeps renewal unattended. A touch for each signature would stop every sandbox's GitHub access each hour until I touch the YubiKey, so this spec does not use it.
- **Check:** `sbx-token check` reports the backend, the slot, and whether the YubiKey answers, before it calls GitHub.
- **Bootstrap:** the dev-mac bootstrap gets the steps to import the key, set the PIN, and delete the file. The YubiKey tool becomes a package.

### C. Fine-grained PATs

- **No App.** `sbx-token` drops the App config, `app_jwt`, and the installation lookup. `mint` prints the cached PAT for the requested repositories.
- **One PAT for each repository set.** The cache key is the sorted list of `owner/name`. Most projects use only the origin repository, so most PATs reach one repository. One PAT can reach the repositories of only one owner, which matches the existing `scope` rule.
- **Pre-fill URL:** `https://github.com/settings/personal-access-tokens/new` with these parameters: `name` (`sbx-<repo>`, 40 characters or fewer), `description` (the repositories, so that I select the correct ones), `target_name` (the owner), `expires_in` (90 by default), and one parameter for each permission (`contents=write`, `pull_requests=write`, `issues=write`, `actions=read`, plus any from `.sbx.json`). The URL cannot pre-select repositories, so I select them by hand.
- **Registration is interactive.** `sbx-token register` runs from `sbx-up` in my terminal. When the cache has no valid PAT for the request, it opens the URL, asks for the token, checks it, and stores it. `mint` never prompts, because the `sbx` daemon runs it without a terminal. A missing or expired PAT makes `mint` fail with the repository and "run sbx-up again".
- **Check on paste:** `sbx-token` calls `GET /repos/{owner}/{repo}` for each repository with the pasted token, and checks that `permissions.push` is true. A token that cannot push to each repository is refused.
- **Expiry:** the expiry date is known when the token is stored (today plus `expires_in`), so it is saved with the token. `doctor` reads the saved dates without a call to GitHub, and warns 14 days before the earliest one. `register` asks for a new PAT 1 day before expiry, so that a sandbox does not start with a token that expires during the session.
- **Storage:** each PAT is a Keychain item (service `sbx-token`, account `pat:<repository set>`). An index of repository sets and expiry dates (no tokens) goes in the config file, so `doctor` and `list` do not have to read the Keychain items.
- **New verbs:** `sbx-token list` prints each repository set with its expiry date. `sbx-token forget <owner/name>…` removes a cached PAT. The PAT on GitHub must still be deleted by hand, because GitHub has no endpoint for an owner to delete a token.
- **Bootstrap:** the App steps are removed. No other step replaces them, because the first `sbx-up` in each repository asks for a PAT.

## Testing Decisions

- A good test runs the real `sbx-token` entry point and checks what the user sees: the exit status, the messages, the calls to external programs, and what goes into the store. It does not call functions in `lib/`.
- **There is one seam: `sbx-token`'s command line, with fakes first on PATH.** This is the seam that the suite already uses. The `sbx-up` tests stay as they are, because the registered command does not change.
- **B:** a fake `yubico-piv-tool` (or whichever YubiKey tool is chosen) signs with the test key from a fixture file, and it records the slot, the policies, and how it received the PIN. The tests check these points:
  - The existing JWT check (`verify_jwt`) passes with the signer.
  - The PEM is never written to the fake Keychain.
  - The PIN never appears on argv.
  - A YubiKey that is not plugged in gives a clear error from `mint` and from `check`.
- **C:** a fake `open` records the pre-fill URL, a paste on stdin answers the prompt, and the fake `curl` answers `GET /repos/{owner}/{repo}` with or without push access. The tests check these points:
  - The URL parameters, including overrides from `.sbx.json`.
  - A refused paste (no push access) stores nothing.
  - The cache lookup for each repository set.
  - `mint` never prompts, and fails with the repository name when the cache has no PAT.
  - The expiry rules in `register` and in `doctor`.
  - `list` and `forget`.
- **Prior art:** `tests/sbx-token.bats` and `tests/helpers.bash` (fakes on PATH, a real test RSA key, and `verify_jwt`). The suite must keep passing under bash 3.2.

## Out of Scope

- A touch on the YubiKey for each token, or tokens that `sbx-up` mints only once at start with no renewal. This would need a different design.
- Generating the key on the YubiKey. GitHub generates the App's key pair, and I have not confirmed that the **Credentials** page accepts a public key of my own.
- The macOS Secure Enclave. It holds only P-256 keys, and GitHub Apps need RS256.
- Classic PATs and OAuth tokens. They cannot be limited to one repository.
- Changes to the host `gh` token.
- The Linux workstation profile. It gets the option chosen here when that profile is built.

## Further Notes

- To confirm before building B:
  - The exact import and sign commands, and how each tool takes the PIN without argv (`ykman`, `yubico-piv-tool`, or `openssl` with a PKCS#11 provider).
  - Whether the slot needs a certificate for the chosen tool to find the key.
  - Whether the `sbx` daemon can reach the YubiKey from its own process.
- To confirm before building C:
  - Whether GitHub accepts every permission parameter at once in the pre-fill URL for a personal account.
  - Whether the `GitHub-Authentication-Token-Expiration` response header is still sent. If it is, the saved expiry can be checked against it.
- The research behind the PAT facts is in `docs/research/fine-grained-gh-tokens-for-sandboxes.md`. The current App design is described in `sbx-token --help` and in the dev-mac bootstrap. Its spec was removed when it was built, and is in the Git history.
