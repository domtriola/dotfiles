# Dev Workflow

Custom tooling in this repo allows for automation of terminal sessions and windows.

- To navigate to a project and start the configured tmux setup:
  - Start a tmux session if not already in one: `tmux`
  - Open the tmux-sessionizer fuzzy navigation: `Ctrl-a f`
  - Choosing a project will switch to that directory and call the local `.ready-tmux` script (or the global default) if one exists

Keep track of workflow reminders in `cheat workflow`. To edit: `cheat -e workflow`.

## Tmux detailed workflow context

### Overview

Three custom scripts work together to automate tmux project navigation:

1. **`tmux-sessionizer`** — Uses `fzf` to browse directories under `~/src`, then creates or switches to a named tmux session for the selected project.
2. **`ready-tmux`** — Runs after a new session is created. Looks for a local `.ready-tmux` script in the project directory; if none exists, falls back to `~/.ready-tmux`.
3. **`.ready-tmux`** (per-project or global) — Defines the windows/panes to set up for that project.

### Custom key bindings (prefix is `Ctrl-a`)

| Binding | Action |
|---------|--------|
| `Ctrl-a f` | Open tmux-sessionizer (fzf project picker) |
| `Ctrl-a r` | Reload `~/.tmux.conf` |
| `Ctrl-a \|` | Split pane horizontally (keeps current path) |
| `Ctrl-a -` | Split pane vertically (keeps current path) |
| `Ctrl-a c` | New window (keeps current path) |
| `Ctrl-a h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl-a H/J/K/L` | Resize panes (vim-style, repeatable) |
