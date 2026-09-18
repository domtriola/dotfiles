# Dev Workflow

Custom tooling in this repo automates tmux sessions and windows.

To open a project:

1. Start a tmux session if not already in one: `troot` (or `tmux`).
2. Open the tmux-sessionizer fuzzy picker: `Ctrl-a f`.
3. Choosing a project switches to a session for that directory. A new session
   then runs the project's `.ready-tmux` script, or the global default.

Keep workflow reminders in `cheat workflow`. To edit them: `cheat -e workflow`.

## Scripts

Five scripts work together. `./sync-env` copies the first four into
`~/.local/bin`.

| Script             | What it does                                                                      |
| ------------------ | --------------------------------------------------------------------------------- |
| `tmux-sessionizer` | Picks a project with `fzf`, then creates or switches to a session named after it. |
| `ready-tmux`       | Runs the project's `.ready-tmux`, or `~/.ready-tmux` if the project has none.     |
| `init-tmux`        | Copies `~/.ready-tmux` into the current directory, as a starting point.           |
| `troot`            | Opens the `~/troot` session, a scratch project for work that belongs to no repo.  |
| `.ready-tmux`      | Per-project or global. Defines the windows and panes to set up.                   |

`tmux-sessionizer` searches a fixed list of directories, held at the top of the
script. It runs `ready-tmux` only for a session it creates, so switching back to
an open session leaves its windows alone.

The session name is the directory name, with `:`, `,`, `.` and spaces replaced
by underscores.

## Custom key bindings

The prefix is `Ctrl-a`.

| Binding          | Action                                       |
| ---------------- | -------------------------------------------- |
| `Ctrl-a f`       | Open tmux-sessionizer (fzf project picker)   |
| `Ctrl-a r`       | Reload `~/.tmux.conf`                        |
| `Ctrl-a \|`      | Split pane horizontally (keeps current path) |
| `Ctrl-a -`       | Split pane vertically (keeps current path)   |
| `Ctrl-a c`       | New window (keeps current path)              |
| `Ctrl-a h/j/k/l` | Navigate panes (vim-style)                   |
| `Ctrl-a H/J/K/L` | Resize panes (vim-style, repeatable)         |

Copy mode uses vi keys: `v` starts a selection and `y` copies it to the system
clipboard, through `pbcopy` on macOS and `wl-copy` on Linux.

## Sandboxes

A `.ready-tmux` does not start the agent sandbox, because `sbx-up` opens its
own windows. Run it separately. See [sbx/README.md](../sbx/README.md).
