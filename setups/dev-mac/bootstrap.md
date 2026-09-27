# dev-mac: manual steps

Steps that are not scripted by `setup`.

## Install git

```sh
xcode-select --install
```

## Set up SSH key

NOTE: run this step after `setup` to create ssh key in [secretive](https://github.com/maxgoedjen/secretive).

1. [ ] Create a new key in secretive
1. [ ] Go through the secretive configuration steps
1. [ ] Add the key to GitHub

## Caps Lock remap (MacOS)

Open System Settings, go to Keyboard > Keyboard Shortcuts > Modifier Keys, and set the Caps Lock key to Control. Repeat it for every attached keyboard, since the setting is per keyboard.

## Disable separate spaces for displays

```
Settings -> Desktop & Dock -> Mission Control -> Displays have separate spaces -> off
```
