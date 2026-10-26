# Threat model: the dev-mac profile

**Kind**: feature
**Product model**: [product.md](product.md)
**Origin**: #109, #122
**Last reviewed**: 2026-10-26

## Scope

This model covers what only the `dev-mac` profile installs and does on the Mac. The commands, the dotfiles, the sandbox kits, the GitHub side, and the sandboxes that the Mac runs are in the [product model](product.md). In the product model, "the host" is the Mac for this profile.

- **The `dev-mac` setup steps** (`profiles/dev-mac/`), and what they download.
- **Its `env.manifest`** and its doctor checks (`profiles/dev-mac/lib/doctor.sh`).
- **The Claude Code managed settings** that `30_tools` installs as root, and host Claude Code on the Mac.
- **The Keychain**, which holds the GitHub App key (product A1) on this profile.
- **The Secure Enclave SSH key** that `40_ssh_key` makes (part of product A4).
- **kamaji on the host**: the `kamaji` wrapper and `kamaji-update` (`env/.local/bin/`), the runtime clone at `~/.local/share/kamaji`, and the `Ctrl-a B` popup. kamaji's own code is in its repository; this model covers only how the Mac runs it.

Out of scope:

- **Everything in the product model.** This model adds to it, and does not repeat it.
- **Physical access** to the Mac, as in the product model.

## Assets

On the Mac, the Keychain holds A1, the Secure Enclave holds the SSH key of A4, and the Mac user account is A5. This profile adds one asset:

- **The kamaji snapshot** (`~/src/personal/kamaji/.kamaji/snapshot.json`): issue titles and bodies from every repository in kamaji's list, private ones too. The kamaji sandbox reads it, by design.

## Actors

- **Host Claude Code**: on the Mac it only authenticates the sandboxes. The managed settings deny it every tool.
- **The kamaji board**: the operator opens it with `Ctrl-a B`. When the operator refreshes it, it mints tokens (A2) from A1 for each owner and writes the snapshot.
- **The kamaji sandbox**: an agent in a sandbox that works in a clone of the kamaji development checkout (product I4), and reads the snapshot through the read-only source mount.
- **Adversary: compromised upstream** (as in the product model), for the installers and packages that this profile's setup steps download.

The other actors are in the product model.

## Entry points

- **Downloads during setup**:
  - The Homebrew installer, uv, nvm, starship, and `get-pnpm` (`profiles/dev-mac/00_preflight`, `15_languages`, `20_packages`).
  - Brew formulae, casks, and taps.
  - The global npm tools.
- **The managed settings file** (`profiles/dev-mac/lib/managed-settings.json`), which host Claude Code reads.
- **kamaji's code and locked dependencies**, which `kamaji-update` takes from `main` on GitHub and installs with `pnpm install --frozen-lockfile`.
- **The kamaji development checkout**, which takes sandbox commits through `sbx-pull` before review (product T12).
- **Issue and PR text** from every repository in kamaji's list, which `kamaji refresh` and `kamaji board` read on the host.

The other entry points are in the product model.

## Trust boundaries

This profile adds no boundary. Its threats cross product boundaries B1 (upstreams to a host), B3 (sandbox to host, through the kamaji development checkout), B4 (host to sandbox, through the snapshot), B5 (untrusted text to the agent, and here to host processes too), and B7 (key handling on the host).

## Data flows

```mermaid
flowchart LR
  subgraph Internet["B1: upstreams"]
    installers[Homebrew installer, uv, nvm, starship, get-pnpm]
    pkgs[brew formulae, casks, taps, global npm tools]
  end
  subgraph Mac["Mac"]
    setup[dev-mac setup steps]
    managed[(managed settings, as root)]
    claude[host Claude Code]
    se[(Secure Enclave: SSH key)]
    runtime[kamaji runtime clone]
    popup[Ctrl-a B popup]
    keychain[(Keychain: A1)]
    devco[(kamaji development checkout)]
  end
  github[GitHub: kamaji main, issues of every listed repo]
  sandbox[kamaji sandbox]

  installers -- scripts run as the operator --> setup
  pkgs -- packages --> setup
  setup -- installs --> managed
  managed -- deny every tool --> claude
  setup -- makes key --> se
  github -- kamaji-update, fast-forward only --> runtime
  popup -- runs --> runtime
  keychain -- sbx-token mint --> runtime
  github -- issue text --> runtime
  runtime -- snapshot --> devco
  devco -- read-only source mount: snapshot --> sandbox
  sandbox -- commits, sbx-pull --> devco
```

## Threats

| ID  | STRIDE | Threat | Boundary | Likelihood | Impact | Status | Mitigation |
| --- | ------ | ------ | -------- | ---------- | ------ | ------ | ---------- |
| dev-mac-T1 | T | An installer script fetched with `curl \| sh` (Homebrew at `HEAD`, uv, starship, `get-pnpm`) is replaced, and runs as the operator. It can also ask for sudo. | B1 | low | high | accepted | None. It is fetched over HTTPS (I1). |
| dev-mac-T2 | T | A brew formula, cask, or tap, or a global npm tool (`sfw`, `socket`), is published with malicious code. None of them has a pinned version. | B1 | low | high | accepted | Package-manager digests. A 7-day minimum release age for pnpm. |
| dev-mac-T3 | E | Host Claude Code acts on the Mac with the operator's full access. | B5 | low | high | mitigated | dev-mac-I1 |
| dev-mac-T4 | I | The operator's SSH key is copied off the Mac. | B7 | low | high | mitigated | dev-mac-I2 |
| dev-mac-T5 | E | A prompt injection makes the kamaji sandbox agent commit code, which `sbx-pull` brings into the development checkout. The popup runs it on the host, before review, with access to A1. | B3, B7 | medium | high | mitigated | dev-mac-I3 |
| dev-mac-T10 | E | The kamaji checkout's `.sbx.json` sets `"clone": false`, so the sandbox mounts it read and write, and writes `.git/config` (for example `core.fsmonitor`) or a hook that the host's git runs (product T10). | B3 | low | high | mitigated | dev-mac-I5 |
| dev-mac-T6 | T | `.kamaji` in the development checkout is a symlink, so the host writes the snapshot into another directory of the operator's. A clone-mode sandbox cannot make one (dev-mac-I5), but a commit that `sbx-pull` brings in could. | B3 | low | medium | mitigated | dev-mac-I4, dev-mac-I5. The check in I4 can lose a race with a process that changes the directory at the same time; only a sandbox in direct mode could be that process. |
| dev-mac-T7 | T | A GitHub user writes an issue on a listed public repository with terminal escape sequences, which `kamaji board` prints in the host terminal, or with instructions for the kamaji sandbox agent, which reads the snapshot. | B5 | medium | low | accepted | None in dotfiles. kamaji must remove control characters before it prints issue text. The agent in the sandbox has the limits of product B5. |
| dev-mac-T8 | I | kamaji prints a token from `sbx-token mint` in the terminal, where the tmux scrollback keeps it. | B7 | low | high | accepted | kamaji must never print a token, as product I8 requires of `sbx-token`. |
| dev-mac-T9 | T | A dependency in kamaji's lockfile is published with malicious code, and runs on the host with access to A1. | B1 | low | high | accepted | `--frozen-lockfile`, so only a lockfile that you reviewed in a PR installs. The 7-day minimum release age for pnpm. |

STRIDE categories that have no threat above: the product model covers them for B1, B3, B4, B5, and B7.

## Security invariants

| ID  | Invariant | Enforced in | Mitigates |
| --- | --------- | ----------- | --------- |
| dev-mac-I1 | `dev-mac` installs the managed settings as root with `deny: ["*"]`, `disableBypassPermissionsMode: "disable"`, and `allowManagedPermissionRulesOnly: true`. Doctor reports a missing or different installed copy. | `profiles/dev-mac/30_tools`, `profiles/dev-mac/lib/managed-settings.json`, `profiles/dev-mac/lib/doctor.sh` | T4 (product), dev-mac-T3 |
| dev-mac-I2 | The SSH key lives in the Secure Enclave with Touch ID protection. Doctor fails when the key is missing or has no Touch ID. | `profiles/dev-mac/40_ssh_key`, `profiles/dev-mac/lib/doctor.sh` | dev-mac-T4 |
| dev-mac-I3 | The host runs kamaji only from the runtime clone. `kamaji-update` fast-forwards it to `main` from GitHub, never from the development checkout, and refuses when the clone has local changes or commits that are not on `main`. The `kamaji` wrapper runs only the runtime clone. Doctor fails when another `kamaji` comes first on PATH, and warns when the runtime clone has local changes. | `env/.local/bin/kamaji`, `env/.local/bin/kamaji-update`, `profiles/dev-mac/lib/doctor.sh` | dev-mac-T5 |
| dev-mac-I4 | The `kamaji` wrapper refuses to run when `.kamaji` in the development checkout is a symlink. It runs kamaji in the runtime clone's directory, so the directory of the pane that opens the popup does not change what kamaji reads. | `env/.local/bin/kamaji` | dev-mac-T5, dev-mac-T6 |
| dev-mac-I5 | Doctor fails when the kamaji checkout's `.sbx.json` sets `"clone": false`, so the kamaji sandbox keeps product I4. | `profiles/dev-mac/lib/doctor.sh` | dev-mac-T6, dev-mac-T10 |

## Accepted risks

| Threat | Reason | Accepted by | Date | Revisit when |
| ------ | ------ | ----------- | ---- | ------------ |
| dev-mac-T7, dev-mac-T8 | kamaji owns these mitigations, in its own repository. Modern terminals block the dangerous escape sequences, as for product T13. | Dominick Triola | 2026-10-23 | kamaji prints issue text or logs its requests. |
| dev-mac-T9 | The same reason as dev-mac-T2, and a lockfile change shows in the PR diff. | Dominick Triola | 2026-10-23 | kamaji adds a dependency with an install script. |
| dev-mac-T1, dev-mac-T2 | Every download comes over HTTPS from the vendor's own source. Package managers check signatures or digests, and Renovate and the 7-day release age apply where they can. On personal machines, pinning every installer costs more to maintain than it reduces the risk. | Dominick Triola | 2026-10-12 | An upstream has a security incident. |

## Assumptions

- The Mac has one user, and FileVault is on.
- The assumptions of the product model.
