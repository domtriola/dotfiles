# The agent-server profile has no Secret Service, so sbx-token keeps the App
# key in a file of mode 600 (see sbx-token --help). import-key saves the choice
# in its config, so the sbx daemon's renewal finds the key without this file.
export SBX_TOKEN_STORE=file
