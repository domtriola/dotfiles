# mosh-server stops when it hears nothing from the client for this many
# seconds. Without it, a session whose laptop never comes back stays open, and
# its key can resume it with no YubiKey (agent-server-I15). Three days covers
# a weekend away. tmux keeps the work when a session stops.
#
# mosh starts mosh-server with a command over SSH, and Ubuntu's bash reads
# ~/.bashrc for such a command, so the server gets this variable.
export MOSH_SERVER_NETWORK_TMOUT=259200
