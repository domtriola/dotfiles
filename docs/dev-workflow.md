# Dev Workflow

The commands in this repo automate tmux sessions and windows.

To open a project:

1. Start a tmux session if not already in one: `troot` (or `tmux`).
2. Open the tmux-sessionizer fuzzy picker: `Ctrl-a f`.
3. Choosing a project switches to a session for that directory. A new session
   then runs the project's `.ready-tmux` script, or the global default.

Keep workflow reminders in `cheat workflow`. To edit them: `cheat -e workflow`.

## Commands

These work together. `sync-env` copies the commands into `~/.local/bin`;
`.ready-tmux` is a file a project holds.

| Command            | What it does                                                                      |
| ------------------ | --------------------------------------------------------------------------------- |
| `tmux-sessionizer` | Picks a project with `fzf`, then creates or switches to a session named after it. |
| `ready-tmux`       | Runs the project's `.ready-tmux`, or `~/.ready-tmux` if the project has none.     |
| `init-tmux`        | Copies `~/.ready-tmux` into the current directory, as a starting point.           |
| `troot`            | Opens the `~/troot` session, a scratch project for work that belongs to no repo.  |
| `.ready-tmux`      | Per-project or global. Defines the windows and panes to set up.                   |

`tmux-sessionizer` searches a fixed list of directories, set in the script. It runs `ready-tmux` only for a session it creates, so switching back to
an open session leaves its windows alone. On a machine without `ready-tmux`
(the `agent-server` profile), a new session is one plain shell.

The session name is the directory name, with `:`, `,`, `.` and spaces replaced
by underscores.

## Custom key bindings

The prefix is `Ctrl-a`.

| Binding          | Action                                        |
| ---------------- | --------------------------------------------- |
| `Ctrl-a f`       | Open tmux-sessionizer (fzf project picker)    |
| `Ctrl-a B`       | Open the kamaji board in a popup              |
| `Ctrl-a r`       | Reload `~/.tmux.conf`                         |
| `Ctrl-a \|`      | Split pane horizontally (keeps current path)  |
| `Ctrl-a -`       | Split pane vertically (keeps current path)    |
| `Ctrl-a c`       | New window (keeps current path)               |
| `Ctrl-a h/j/k/l` | Navigate panes (vim-style)                    |
| `Ctrl-a H/J/K/L` | Resize panes (vim-style, repeatable)          |
| `Ctrl-a Ctrl-a`  | Send `Ctrl-a` to the program in the pane      |
| `F12`            | Turn this tmux's keys off or on (nested tmux) |

Copy mode uses vi keys: `v` starts a selection and `y` copies it. The copy goes
to the terminal's clipboard through OSC 52, which works over SSH. Where `pbcopy`
or `wl-copy` is installed, the copy also goes to it.

A program in a pane cannot set or read the clipboard through OSC 52. This
stops a sandbox agent in a tmux window from changing what you paste.

## A tmux on another machine

To work in a tmux on a remote machine, open a new terminal window. Do not
start the local tmux in it. Then attach to the remote tmux:

```console
ssh -t <host> tmux new -A -s main
```

Then every key goes to the remote tmux. The remote tmux keeps its sessions when
the connection closes, so attach again with the same command. Over SSH, the
status bar shows the hostname before the session name, for each client that
attaches over SSH.

When the remote tmux runs inside the local one, the local tmux gets `Ctrl-a`
first. There are two ways to reach the remote tmux:

- Press `F12`. The local tmux turns its keys off and shows `OFF` in the status
  bar, so every key goes to the remote tmux. Press `F12` again to turn them
  back on.
- Press `Ctrl-a Ctrl-a`, then the key. The local tmux sends one `Ctrl-a` to the
  remote tmux.

A copy in the remote tmux does not reach the local clipboard when the remote
tmux runs inside the local one. The local tmux ignores OSC 52 from its panes.
To copy, use the remote tmux in its own terminal window.

## Sandboxes

A `.ready-tmux` does not start the agent sandbox, because `sbx-up` opens its
own windows. Run it separately. See [sbx/README.md](../sbx/README.md).
