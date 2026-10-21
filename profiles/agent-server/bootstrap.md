# Agent server: bootstrap

Every step by hand, from a bare drive 1 of the Framework Desktop to a box where agents run in sandboxes. The setup steps in this directory do the rest. The threat model for this profile is [`docs/threat-model/profile-agent-server.md`](../../docs/threat-model/profile-agent-server.md).

The firmware settings and the identity of each drive (hostname `doms-agents`, SSH alias `doms-agents`) are in [the Framework Desktop document](../../docs/framework-desktop.md). Do those first.

You need a USB keyboard with a cable, a monitor, an Ethernet cable, a USB drive of 8 GB or more, the Mac, and the YubiKey.

## 1. Install Ubuntu Server on drive 1

1. Write the Ubuntu Server 26.04 image to the USB drive, as in step 1 of [the `ai-server` bootstrap](../ai-server/bootstrap.md).
2. Connect the Ethernet cable. The installer writes the network configuration that it sees. With no cable, the installed system gets IPv6 only.
3. Record the model and serial of drive 1 (`lsblk -o NAME,SIZE,MODEL,SERIAL` from drive 2). Then put in the USB drive, restart, tap **F12**, and select **EFI USB Device**.
4. In the installer:
   - **Storage**: **Use an entire disk**, drive 1 (check the model and serial two times), with **Set up this disk as an LVM group** and **Encrypt the LVM group with LUKS**. Put the passphrase in your password manager. You type it at each start of the box, at its keyboard.
   - **Profile**: the server's name is `doms-agents`. Use a strong password: `sudo` asks for it, and you need it at the keyboard if SSH fails.
   - **SSH**: **Install OpenSSH server**. Keep password login on until step 3.
   - **Featured server snaps**: none.
5. Unlock the disk, and log in at the console. Set the boot order, as the Framework Desktop document says.

## 2. SSH from the Mac on the LAN

Add the `doms-agents` entry to `~/.ssh/config.d/hosts` on the Mac, with the LAN address for now (`ip -br a show scope global` on the box):

```text
Host doms-agents
  HostName <address of the box>
  User <your username on doms-agents>
  HostKeyAlias doms-agents
```

Then copy the Mac's key, and check that the key alone is enough:

```console
ssh-copy-id -i ~/.ssh/id_ecdsa_sk.pub doms-agents
ssh -o PasswordAuthentication=no doms-agents
```

If `ssh` says "No route to host", turn on the terminal app in **System Settings → Privacy & Security → Local Network** on the Mac, then open the app again.

## 3. SSH with the YubiKey

The box accepts only a key that asks for a PIN and a touch. The Mac's own `ssh` cannot use a FIDO key, so use Homebrew's OpenSSH for this key:

```console
brew install openssh
$(brew --prefix)/bin/ssh-keygen -t ed25519-sk -O verify-required -f ~/.ssh/id_ed25519_sk -C "yubikey doms-agents"
$(brew --prefix)/bin/ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub doms-agents
```

Add these lines to the `doms-agents` entry. The `Host *` block of `~/.ssh/config` sets the Secure Enclave provider, and the entry comes first, so it wins:

```text
  IdentityFile ~/.ssh/id_ed25519_sk
  SecurityKeyProvider internal
```

Check that the YubiKey asks for its PIN and a touch: `$(brew --prefix)/bin/ssh doms-agents`. Then, on the box, remove the Mac's Secure Enclave key (the `sk-ecdsa-sha2-nistp256@openssh.com` line) from `~/.ssh/authorized_keys`. `05_hardening` stops when there is no YubiKey key, and `doctor` fails while a key that is not a security key is there.

## 4. Clone the repository and run the profile

Over SSH with the YubiKey:

```console
mkdir -p ~/src/personal && cd ~/src/personal
git clone https://github.com/domtriola/dotfiles.git
cd dotfiles
./commands/setup/setup --profile agent-server --dry
./commands/setup/setup --profile agent-server
./commands/sync-env/sync-env
```

The real run saves the profile, and later runs reuse it. A dry run saves nothing. Ubuntu detects no profile, so that neither drive gets the other's profile by a wrong guess.

`25_network` skips the NetBird registration on this run, because it needs a setup key. Log out and in again, so that the `kvm` group applies.

## 5. Join NetBird, and move SSH to it

Take a one-off setup key from the NetBird dashboard. In the dashboard, delete the "Default" policy, and make one policy: source your client group, destination this machine, TCP port 22, one way. Connect the Mac to NetBird. Then, on the box:

```console
read -rs -p 'Setup key: ' NETBIRD_SETUP_KEY && export NETBIRD_SETUP_KEY
setup 25_network
unset NETBIRD_SETUP_KEY
```

`read -s` keeps the key out of the screen and the shell history.

When a peer is connected, SSH moves to the NetBird interface `wt0`, and the LAN cannot reach it. Before you close the session, change `HostName` of the `doms-agents` entry to the address that the step prints, and check that `ssh doms-agents` works. If it does not, use the box's keyboard.

## 6. Sign in to sbx, and import the App key

```console
sbx login
```

The box has its own private key of the GitHub App, so that you can revoke it without an effect on the Mac. On the App's settings page, under "Private keys", generate a new key. Copy the `.pem` file to the box, import it into the file store, and delete it:

```console
scp ~/Downloads/<app>.pem doms-agents:
ssh doms-agents
SBX_TOKEN_STORE=file sbx-token import-key --app-id <id> ~/<app>.pem
rm ~/<app>.pem
sbx-token check
```

Also delete the `.pem` file on the Mac. `import-key` saves the file store in its config, so the hourly token renewal (which the sbx daemon runs, not your shell) finds the key.

## 7. Check the box

```console
doctor
```

Every check must be `ok`. Then start agents inside tmux, so that they keep running after you disconnect:

```console
tmux new -s agents
cd ~/src/<project> && sbx-up
```

## Later

- **Updates** install by themselves and never restart the box, because a restart stops it at the LUKS prompt. When `doctor` reports that a reboot is required, run `sudo reboot` when you are at the box, and type the passphrase.
- **A power cut** starts the box again (Power On AC Attach), and it waits at the LUKS prompt.
- **Revoke the box's App key** on the App's settings page. The Mac's key keeps working.
