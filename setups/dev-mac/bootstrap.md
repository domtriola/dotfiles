# dev-mac: manual steps

Steps that are not scripted by `setup`.

## Install git

```sh
xcode-select --install
```

## Enroll Touch ID fingers

Do this before you run `setup`. The SSH key from `40_ssh_key` needs Touch ID for each use, and it has no password fallback.

1. [ ] Open System Settings > Touch ID & Password, and enroll multiple fingers.

## Set up SSH key

NOTE: run this step after `setup`, because `40_ssh_key` creates the key.

1. [ ] Add the key to GitHub for authentication and for signing. Use the web UI, not `gh`, because a stored `gh` token lets any process that runs as you use your repositories without Touch ID.

   1. Copy the public key:

      ```sh
      pbcopy < ~/.ssh/id_ecdsa_sk.pub
      ```

   1. Go to https://github.com/settings/keys, and click **New SSH key**.
   1. Set the title to the hostname (`hostname -s`), set the key type to **Authentication Key**, paste the key, and click **Add SSH key**.
   1. Do the same steps again, with the key type set to **Signing Key**.

1. [ ] Test it: `ssh -T git@github.com`, and make a signed commit.

### Recover the SSH key

The key cannot be exported, so it has no backup. If Touch ID stops working for the key (for example, after a Touch ID reset), replace the key:

1. Remove the old key and its reference:

   ```sh
   sc_auth list-ctk-identities -t ssh   # find the hash of the "ssh" key
   sc_auth delete-ctk-identity -h <hash>
   rm ~/.ssh/id_ecdsa_sk ~/.ssh/id_ecdsa_sk.pub
   ```

1. Run `40_ssh_key` again to make a new key.
1. At https://github.com/settings/keys, delete the old key from both the authentication and the signing lists. Then add the new key with the steps above.

## Caps Lock remap (MacOS)

Open System Settings, go to Keyboard > Keyboard Shortcuts > Modifier Keys, and set the Caps Lock key to Control. Repeat it for every attached keyboard, since the setting is per keyboard.

## Disable separate spaces for displays

```
Settings -> Desktop & Dock -> Mission Control -> Displays have separate spaces -> off
```
