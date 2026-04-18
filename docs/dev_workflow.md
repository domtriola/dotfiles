# Dev Workflow

Custom tooling in this repo allows for automation of terminal sessions and windows.

- To navigate to a project and start the configured tmux setup:
  - Start a tmux session if not already in one: `tmux`
  - Open the tmux-sessionizer fzf navigation: `Ctrl-a f`
  - Go to project
  - This will switch to that directory and call the local `.ready-tmux` script (or the global default) if one exists
