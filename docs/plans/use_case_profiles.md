# Plan: Use-Case Profiles

Refactor `setups/` from OS-based dispatch to use-case profiles, then add an
`sbx` mixin that pulls this repo into a sandbox and runs the setup.

## Goal

A machine declares what it is **for**, not what OS it runs. Four profiles:

| Profile        | Machine                            | Replaces                                 |
| -------------- | ---------------------------------- | ---------------------------------------- |
| `dev-mac`      | macOS workstation                  | `setups/macos`                           |
| `dev-linux`    | Fedora dev box                     | `setups/linux` + `linux/fedora`          |
| `travel-qubes` | Qubes appVM (minimal, no installs) | the qubes branch in `fedora/20_packages` |
| `sbx-linux`    | Docker Sandbox (Ubuntu)            | (new)                                    |

Duplication between profiles is accepted. `setups/shared/` goes away.

## Decisions

1. **Profile selection.** `./setup --profile <name>` writes the name to
   `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile`. Later runs need no
   flag. `$DOTFILES_PROFILE` overrides the file (this is how the mixin sets it).
   Auto-detection only proposes a default on first run and must be confirmed.
2. **`sync-env` becomes profile-aware.** Each profile owns an `env.manifest`
   that lists the items to copy. `sync-env` becomes a copier driven by that list.
3. **`sbx-linux` scope.** Env sync plus a small CLI set (`jq`, `fzf`, `ripgrep`,
   `tree`, `neovim`, `tmux`) by way of `apt-get`.
4. **Mixin source.** The mixin clones `https://github.com/domtriola/dotfiles`
   at sandbox startup into `~/src/personal/dotfiles`. The ref defaults to `main`
   and is overridable with `$DOTFILES_REF`, so a branch can be tested before it
   merges.

## Facts confirmed about the sandbox

- Ubuntu 26.04, package manager is `apt-get` (**not** `dnf`).
- User is `agent`, uid `1000`, with passwordless `sudo`.
- Detection markers: `$SANDBOX_NAME` is set, and `/etc/sandbox-persistent.sh`
  exists. `/run/sandbox` exists only in `--clone` mode, so do not detect on it.

## Target layout

```
setups/
  lib/
    platform.sh        # is_mac, is_linux, is_qubes, is_sandbox, ...
    profile.sh         # resolve, validate, persist the profile
  dev-mac/
    env.manifest
    00_bootstrap 10_settings 15_languages 20_packages 30_setup
  dev-linux/
    env.manifest
    10_settings 15_languages 20_packages
  travel-qubes/
    env.manifest
    10_settings
  sbx-linux/
    env.manifest
    20_packages
sbx/kits/mixins/dotfiles/
  spec.yaml
  README.md
```

### `env.manifest` format

One directive per line, `#` for comments. `sync-env` maps each directive onto
the copy helper it already has:

```
group   General directories
subdirs .config           $HOME/.config
file    .local/bin/troot  $HOME/.local/bin
dir     .bashrc.d         $HOME/.bashrc.d
```

## Safety rules for every step

- Work on a branch. One commit per step.
- `--dry` never writes anything, and that includes the profile file.
- Before a step that changes behaviour, capture `./setup --dry` and
  `./sync-env --dry` output, then diff the new output against it.
- Test order is least destructive first: sandbox, then Qubes, then the Fedora
  box, then the Mac last.
- `sync-env` removes its destination before it copies. Step 5 adds a guard that
  refuses to run on a missing or empty manifest, so a typo cannot empty `$HOME`.

---

## Steps

### Step 1 (Profile resolution, inert)

Add `setups/lib/profile.sh` and teach `setup` the `--profile` flag, but keep the
existing OS dispatch. Nothing about which scripts run changes yet.

- `resolve_profile`: `$DOTFILES_PROFILE` > `--profile` > profile file > detect
  and confirm.
- `detect_profile`: darwin gives `dev-mac`, a qubes kernel gives `travel-qubes`,
  a sandbox marker gives `sbx-linux`, any other Linux gives `dev-linux`.
- `assert_compatible`: refuse `dev-mac` on Linux (and the reverse), so a wrong
  profile file cannot run `brew` on Fedora.
- `persist_profile`: write the file, but never during a dry run.

**Test:** `./setup --dry` prints the same script list as before, plus the
resolved profile. `./setup --profile dev-mac --dry` on Linux fails the guard.
No file is written by any dry run.

### Step 2 (Rename directories, mechanical only)

`git mv` only, no edits to script bodies:

- `setups/macos` -> `setups/dev-mac`
- `setups/linux/fedora` -> `setups/dev-linux`
- `setups/linux/15_languages` -> `setups/dev-linux/15_languages`
- remove the now empty `setups/linux`

Change `setup` to dispatch on the profile (`run_dir setups/$profile`).
`setups/shared` still runs for every profile at this point.

**Test:** on each machine, `./setup --dry` lists the same scripts as the step-1
output, with the new paths.

### Step 3 (Dissolve `setups/shared`)

`setups/shared/20_packages` installs starship, ollama, the pi agent and hermes.
Copy it into the profiles that want it and drop the `shared` dispatch.

Proposal, to confirm when we get here:

| Tool     | dev-mac | dev-linux | travel-qubes | sbx-linux |
| -------- | ------- | --------- | ------------ | --------- |
| starship | yes     | yes       | no           | yes       |
| ollama   | yes     | yes       | no           | no        |
| pi agent | yes     | yes       | no           | no        |
| hermes   | no      | yes       | no           | no        |

**Test:** diff the `./setup --dry` script list against step 2. The only expected
difference is `shared/20_packages` replaced by the per-profile copy.

### Step 4 (Add `travel-qubes` and `sbx-linux`)

- `travel-qubes/10_settings`: the `gsettings` key-repeat calls from the current
  `fedora/10_settings`. No package install.
- Remove the `uname -r | grep qubes` branch from `dev-linux/20_packages`, since
  the profile now carries that distinction.
- `sbx-linux/20_packages`: an `apt-get` install, guarded so it is a no-op when
  the tools are already present. Packages: jq, fzf, ripgrep, tree, neovim, tmux
  and starship.
  Starship comes from apt here, and not from its own installer, because the
  sandbox network policy blocks `starship.rs` by default. Ubuntu 26.04 packages
  starship 1.22.1, and `apt-get` reaches `ports.ubuntu.com` from the sandbox.
  For the same reason, `sbx-linux` gets no `25_tools`: every tool in that file
  comes from a domain the sandbox does not allow.

**Test:** run `sbx-linux` inside a throwaway sandbox (fully disposable). Dry-run
`travel-qubes` on the Qubes appVM, then run it for real (settings only, so it is
cheap to undo).

### Step 5 (Manifest-driven `sync-env`)

Add an `env.manifest` to each profile and rewrite `sync-env` to parse it. Keep
`--dry`, add `--profile`, add the empty- or missing-manifest guard.

Starting point per profile:

- `dev-mac`: everything it copies today, including hammerspoon.
- `dev-linux`: the same, minus hammerspoon.
- `travel-qubes`: shell, tmux, nvim and git config only. No `.claude`, no
  `.aws`, no `sbx-up`/`sbx-pull`.
- `sbx-linux`: shell, tmux, nvim, git and `.claude`. No hammerspoon, no
  `tmux-sessionizer`, no `hermes-backup`.

**Test:** for `dev-mac`, diff `./sync-env --dry` against the pre-step output and
confirm that nothing is missing. Only then run it for real.

### Step 6 (Docs)

Update `README.md` (fresh-system steps now name a profile) and `sbx/README.md`.

### Step 7 (The `dotfiles` mixin)

Create `sbx/kits/mixins/dotfiles`. Read the live kit spec first (the
`kit-author` skill has the links), since the schema moves between releases.

A startup hook, as user `1000`, that:

1. Clones `${DOTFILES_REPO:-https://github.com/domtriola/dotfiles}` at
   `${DOTFILES_REF:-main}` into `~/src/personal/dotfiles`.
2. Exports `DOTFILES_PROFILE=sbx-linux`.
3. Runs `./sync-env` and then `./setup`.

A failed clone stops the sandbox. A sandbox that silently starts without the
dotfiles is harder to diagnose than one that refuses to start.

Open item for this step: confirm `github.com` is allowed by the network policy.

**Test:** `sbx run ./sbx/kits/sandboxes/my-claude --kit ./sbx/kits/mixins/dotfiles`
with `DOTFILES_REF` pointing at this branch, before anything merges to `main`.

### Step 8 (Adopt it by default, last)

Add `dotfiles` to the default kit list in `env/.local/bin/sbx-up` and to this
repo's `.sbx.json`. This changes every sandbox you start, so it lands only after
step 7 is proven.

## Dependencies

Steps 1 to 6 are sequential. Step 7 needs steps 4 and 5 on a **pushed** branch,
because the sandbox clones from GitHub and not from the working tree. Step 8 is
last.
