# dev-mac: manual steps

Steps that are not scripted by `setup`.

## Install git

```sh
xcode-select --install
```

## Set up SSH key

NOTE: run this step after `setup`, because `40_ssh_key` creates the key.

1. [ ] Add the key to GitHub for authentication and for signing:

   ```sh
   gh ssh-key add ~/.ssh/id_ecdsa_sk.pub --type authentication --title "$(hostname -s)"
   gh ssh-key add ~/.ssh/id_ecdsa_sk.pub --type signing --title "$(hostname -s)"
   ```

1. [ ] Test it: `ssh -T git@github.com`, and make a signed commit.

## Caps Lock remap (MacOS)

Open System Settings, go to Keyboard > Keyboard Shortcuts > Modifier Keys, and set the Caps Lock key to Control. Repeat it for every attached keyboard, since the setting is per keyboard.

## Disable separate spaces for displays

```
Settings -> Desktop & Dock -> Mission Control -> Displays have separate spaces -> off
```
