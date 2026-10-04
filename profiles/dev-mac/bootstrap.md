# dev-mac: manual steps

Steps that are not scripted by `setup`.

## Install git

```sh
xcode-select --install
```

## Enroll Touch ID fingers

Do this before you run `setup`. The SSH key from `40_ssh_key` needs Touch ID for each use, and it has no password fallback. If Touch ID is not reliable for you, see [Use a key without Touch ID](#use-a-key-without-touch-id).

1. [ ] Open System Settings > Touch ID & Password, and enroll multiple fingers.

## Set up SSH key

NOTE: run this step after `setup`, because `40_ssh_key` creates the key.

1. [ ] Add the key to GitHub for authentication and for signing. Use the web UI. The `gh` token (see [Set up the GitHub CLI](#set-up-the-github-cli)) cannot manage keys.

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

### Use a key without Touch ID

`sc_auth` can protect the key with Touch ID only (`bio`) or with nothing (`none`). It cannot fall back to a password. If Touch ID is not reliable for you, you can make a key with `none` protection. Then any process that runs as you can use the key without a prompt, so `doctor` reports it as a failure. Use it only until a YubiKey replaces it.

1. If a key exists, remove it as in step 1 of [Recover the SSH key](#recover-the-ssh-key).
1. Make the new key:

   ```sh
   SSH_KEY_PROT=none setup 40_ssh_key
   ```

1. Replace the key on GitHub as in step 3 of [Recover the SSH key](#recover-the-ssh-key).

Later runs of `setup` keep the key, and show a warning.

## Set up the GitHub CLI

`gh` stores its token where any process that runs as you can read it. So the token gets only the permissions that issue management needs, and it cannot read code, push, or delete repositories. Git operations use the SSH key.

1. [ ] At https://github.com/settings/personal-access-tokens, make a fine-grained token:
   - Repository access: only the repositories whose issues you manage.
   - Permissions: **Issues** read and write. **Metadata** read-only is added automatically. Give no other permissions.
   - Expiration: 90 days or less.
1. [ ] Copy the token, then log in:

   ```sh
   pbpaste | gh auth login --with-token --git-protocol ssh && pbcopy </dev/null
   ```

1. [ ] Test it: `gh issue list --repo <owner>/<repo>`.

When the token expires, make a new one and log in again.

## Caps Lock remap (MacOS)

Open System Settings, go to Keyboard > Keyboard Shortcuts > Modifier Keys, and set the Caps Lock key to Control. Repeat it for every attached keyboard, since the setting is per keyboard.

## Disable separate spaces for displays

```
Settings -> Desktop & Dock -> Mission Control -> Displays have separate spaces -> off
```
