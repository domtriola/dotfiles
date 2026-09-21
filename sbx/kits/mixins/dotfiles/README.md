# dotfiles

A mixin kit that clones this dotfiles repo into the sandbox and applies it with
the `sbx-linux` profile, so a sandbox shell matches the other machines this
repo sets up.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/dotfiles
```

## Settings

Four variables in `spec.yaml` decide what the startup hook does:

| Variable                | Default                                 | Meaning                                                            |
| ----------------------- | --------------------------------------- | ------------------------------------------------------------------ |
| `DOTFILES_REPO`         | `https://github.com/domtriola/dotfiles` | The repo to clone.                                                 |
| `DOTFILES_REF`          | `main`                                  | The branch or tag to check out.                                    |
| `DOTFILES_PROFILE`      | `sbx-linux`                             | The profile `./sync-env` and `./setup` use.                        |
| `DOTFILES_NVIM_PREWARM` | `1`                                     | Install the nvim plugins in the background. Set to `0` to skip it. |

To test a branch before it merges, change `DOTFILES_REF` and start a sandbox:

```console
sbx run ./sbx/kits/sandboxes/my-claude --kit ./sbx/kits/mixins/dotfiles
```

## Knowing when it has finished

The hook takes about twenty seconds: a clone, then roughly 150 MB of packages.
A shell opened before it finishes has the dotfiles but not yet the tools. The
nvim plugins take longer, and no shell waits for them.

These files under `$HOME` report the state:

| File                          | Meaning                                               |
| ----------------------------- | ----------------------------------------------------- |
| `~/.dotfiles-kit.log`         | Everything the hook printed. Rewritten on each start. |
| `~/.dotfiles-kit.status`      | The current step, then `ready` or `failed`.           |
| `~/.dotfiles-kit.done`        | Written only after the last step succeeds.            |
| `~/.dotfiles-kit.nvim-status` | The background plugin install, with its own `ready`.  |
| `~/.dotfiles-kit.nvim.log`    | Everything the background plugin install printed.     |

The status file exists so that a wait is not a blank screen: `sbx-wait` polls it
and names the step it is waiting on, and stops early on `failed` rather than
running out its timeout. The step names are short phrases meant to be read in
a progress line, not parsed.

To check by hand, use the absolute path, since a `~` in an `sbx exec` command is
expanded by the host shell and never reaches the container:

```console
sbx exec <name> -- cat /home/agent/.dotfiles-kit.log
sbx exec <name> -- cat /home/agent/.dotfiles-kit.nvim.log
```

## Notes

- **A failure does not stop the sandbox.** The engine starts it anyway, so the
  hook has to leave its own evidence: the log, and `failed` in the status file.
  `sbx-wait` reads both and prints the end of the log rather than opening a
  shell on a silently unconfigured sandbox.
- **Do not commit from the clone.** It is shallow, the checkout is detached,
  and every start resets it. Edit the dotfiles in their own project instead.
- Both `./sync-env` and `./setup` are idempotent, so a restart costs little:
  the packages are already there, and the files are copied again.
- The `sbx-linux` manifest leaves the agent skills out on purpose. The
  [`agent-skills`](../agent-skills/README.md) kit delivers those before the
  agent starts, and this hook runs about twenty seconds later.
