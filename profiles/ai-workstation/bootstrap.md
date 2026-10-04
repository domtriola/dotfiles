# AI workstation: manual bootstrap

Every step from a bare Framework Desktop to the point where the
`ai-workstation` profile can run, and the steps after it that need a person.
This is the source of truth for those steps.

The workstation goes on **drive 1**, which held Fedora (`dev-linux`). Drive 2
keeps the `ai-server` install as a cold fallback, and is not touched.

Nothing here is scripted, and each step says why. Everything between step 8
and [After setup](#after-setup) is done by the scripts in this directory.

The Ubuntu side of this follows
[their networking](https://ubuntu.com/server/docs/#networking) and
[security](https://ubuntu.com/server/docs/#security) documentation.

## 1. Write the installer to a USB drive

Download the Ubuntu Server image from
<https://releases.ubuntu.com/26.04/>, then check it against the `SHA256SUMS`
file in the same directory:

```console
cd ~/Downloads
curl -O https://releases.ubuntu.com/26.04/SHA256SUMS
shasum -a 256 --check --ignore-missing SHA256SUMS
```

`--ignore-missing` checks the one image that was downloaded and skips the rest
of the list.

On macOS, write the image with [balenaEtcher](https://etcher.balena.io/):
flash from the ISO, select the USB drive, then flash.

## 2. Install Ubuntu Server

Server, not Desktop. The machine is headless, and every UI an agent builds is
checked on another machine.

**Connect an Ethernet cable before starting the installer.** The installer
writes the network configuration it observes. With no carrier it writes no
`dhcp4` key, and the installed machine then comes up with IPv6 only, which
step 5 has to repair by hand.

1. Insert the USB drive and restart the machine.
2. Hold **F12** during start to reach the Framework boot menu.
3. Start the USB drive.
4. Work through the installer. Two answers matter more than the rest:
   - **Which disk.** Drive 1, the one that held Fedora. Record the model and
     serial number of both drives first, with
     `lsblk -o NAME,SIZE,MODEL,SERIAL`, and find the one with the Fedora
     partitions. Use manual partitioning, select only that drive, and let the
     installer make a new EFI system partition on it. Choosing the wrong drive
     here erases the ai-server fallback. A second EFI partition keeps a failed
     install from stopping the other operating system from starting.
   - **Encrypt the disk, with a passphrase.** This is the chosen design: a
     drive that leaves the machine is unreadable. The cost is that every boot
     needs a person at the console to type the passphrase, so the machine stays
     down after a power cut until someone is there. Unattended unlock (TPM2
     through Clevis, or Dropbear) is a deferred decision, recorded in
     [docs/ai-workstation.md](../../docs/ai-workstation.md). Keep the
     passphrase somewhere other than this machine.
5. On the "installation complete" screen, remove the USB drive, then restart.

## 3. Set the boot order

The machine should start as the workstation by default, with the ai-server
drive second, so that a restart returns the workstation.

Set the order in the Framework firmware setup, or from the installed system:

```console
sudo efibootmgr                         # note the entry numbers
sudo efibootmgr -o <workstation>,<ai-server>
```

Both installs are Ubuntu, so both entries can be called `ubuntu`. Tell them
apart by the partition GUID at the end of each line, against the output of:

```console
sudo blkid -s PARTUUID -o value /dev/<drive-1-efi-partition>
```

To boot the fallback once, without changing the order, hold **F12** at start
and choose the drive 2 entry. Both installs have their own SSH host keys and
NetBird peers, so a client sees them as different machines.

## 4. Claim the rest of the disk

The Ubuntu Server installer builds an LVM volume group across the whole drive
and then gives the root volume about 100 GB. The remainder stays unallocated in
the volume group, so a 1 TB disk presents as a 98 GB filesystem.

This matters here more than on most servers. One model is 20 to 120 GB, and
every sandbox holds its own disk image, so the default fills up within days.

```console
sudo vgs    # VFree is what was never handed out
sudo lvs    # LSize of the root volume
```

`12_storage` does this during `setup`, and asks first. Run it by hand only
to do it before then, or to answer differently:

```console
sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
df -h /
```

`-r` grows the filesystem in the same step, and both ext4 and XFS do that
online.

LUKS sits below the volume group, so an encrypted install needs nothing extra.

The script takes all of the free extents, set by `$AI_WORKSTATION_LV_FREE_PCT`.

**One volume holds everything**: the system, its packages, the logs, the
models and the sandboxes. This was chosen over a separate volume for models.
`ai-model add` refuses a download that would not fit, and `doctor` warns at 85
percent use. When it warns, the usual cause is finished sandboxes:

```console
sbx ls
sbx rm <name>
```

What keeps that from stopping the system is the ext4 reserve, not a margin in
the volume group. ext4 holds back a share of its blocks for root, so a
filesystem that is full to a normal user still works for root-owned processes,
and that reserve grows with the filesystem. Extents held back in the volume
group protect nothing by comparison, because nothing can use them until they
are allocated.

Check the reserve, and lower it if the space matters more than the margin:

```console
sudo tune2fs -l /dev/ubuntu-vg/ubuntu-lv | grep -i 'reserved block count'
sudo tune2fs -m 1 /dev/ubuntu-vg/ubuntu-lv   # 5 percent down to 1
```

## 5. Check the network

```console
ip -br a show scope global
ip route | head -2
```

An IPv4 address and a `default via ...` line mean this step is done.

`ip route` prints IPv4 routes only, so an empty result together with addresses
ending in `/64` and `/128` means the machine has IPv6 and no IPv4. That is the
case step 2 warns about. Repair it with a drop-in file, which leaves the
installer's own file alone:

```console
IFACE=$(ip -br link | awk '$1 ~ /^en/ && $2 == "UP" {print $1; exit}')
echo "Configuring: $IFACE"

sudo tee /etc/netplan/99-ipv4-dhcp.yaml >/dev/null <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: true
EOF

sudo chmod 600 /etc/netplan/99-ipv4-dhcp.yaml
sudo netplan try
```

`netplan try` restores the previous configuration after 120 seconds unless it
is confirmed. Use `try` and never `apply` on a machine reached over the
network.

This step is manual because the repository cannot be cloned before the network
works.

**Do it over SSH rather than at the console.** An IPv6-only machine is still
reachable: install the SSH server first (step 6), note the global IPv6 address,
and connect to that. Then repair IPv4 from the client, where `netplan try` can
be confirmed in one terminal while a second proves the connection still works.

```console
ssh <user>@<ipv6-address>          # the /64 beginning 2..., not the fe80 one
```

If the client has no IPv6 on that network, the link-local address works on the
same switch, with the client's interface appended:
`ssh <user>@fe80::...%en0`.

## 6. Install the SSH server

```console
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y openssh-server git
ip -br a show scope global
```

Upgrade before the profile runs, rather than after. A kernel upgrade later
means another restart, and `15_gpu` already asks for one.

Note the address. Connect from the client to confirm it answers:

```console
ssh <user>@<address>
```

Ubuntu Server does not always include `git`, and step 8 needs it to clone the
repository before `10_packages` can install anything.

This step is manual because `05_hardening` turns password authentication off,
and there has to be a working way in before that happens.

## 7. Copy an SSH key from the client

Check the server first. The installer offers to import an SSH identity from
GitHub, and if that was accepted there is nothing to do:

```console
cat ~/.ssh/authorized_keys
```

Otherwise run this **on the client**, while password authentication still
works. On a `dev-mac` client, `profiles/dev-mac/40_ssh_key` makes the key:

```console
ssh-copy-id -i ~/.ssh/id_ecdsa_sk.pub <user>@<server-address>
```

Then prove that the key alone is enough, in a second terminal, keeping the
first one open:

```console
ssh -o PasswordAuthentication=no <user>@<server-address>
```

This step is manual because it runs on the client and not on the server.

`05_hardening` stops when `~/.ssh/authorized_keys` is empty, so a missed step
here fails loudly rather than locking the machine.

### Replacing the client key

After `05_hardening`, password authentication is off, so `ssh-copy-id` cannot
add a new key. A key that is not in `~/.ssh/authorized_keys` fails with
`Permission denied (publickey)`. Add the new key before the old one is deleted:

1. On the client, add the new public key to GitHub as an **authentication**
   key. (Note: if you don't intend to use this key with GitHub, then an alternate option is to copy it over via USB)
2. On the server, from a session that still works or at the console, append
   the new key. Use a part of the key that no other key has, such as its last
   characters:

   ```console
   curl -fsS https://github.com/<github-user>.keys | grep -F '<part of the new key>' >> ~/.ssh/authorized_keys
   ```

3. Compare the fingerprints. One line on the server must match the client:

   ```console
   ssh-keygen -lf ~/.ssh/authorized_keys     # server
   ssh-keygen -lf ~/.ssh/id_ecdsa_sk.pub     # client
   ```

4. From the client, log in with the new key, and keep that session open.
5. In that session, delete the old key. The key contains `/` and `+`, so
   `grep -F` is safer than a `sed` pattern:

   ```console
   grep -vF '<part of the old key>' ~/.ssh/authorized_keys > /tmp/authorized_keys
   install -m 600 /tmp/authorized_keys ~/.ssh/authorized_keys && rm /tmp/authorized_keys
   ```

6. Log in again from a second terminal to prove that the new key still works,
   then remove the old key from GitHub.

## 8. Clone the repository and run the profile

```console
mkdir -p ~/src/personal && cd ~/src/personal
git clone https://github.com/domtriola/dotfiles.git
cd dotfiles
./commands/setup/setup --profile ai-workstation --dry
./commands/setup/setup
```

Name the profile once. It is saved, and later runs reuse it.

Run `--dry` first. The real run installs packages and rebuilds the boot
configuration.

`15_gpu` asks which IOMMU setting to use, and explains both. Set
`$AI_WORKSTATION_IOMMU` to `off` or `pt` to answer without being asked.

Run `./commands/sync-env/sync-env` to pull environment configs. It also puts
the commands that `env.manifest` lists on PATH, so later runs need no path.

## After setup

### Restart, and check the GPU memory

`setup` reports when the kernel parameters change. Restart then (at the
console, because of the passphrase), and confirm that the GPU has the memory it
was given:

```console
for d in /sys/class/drm/card*/device; do
  [ -f "$d/mem_info_gtt_total" ] && echo "GTT: $(( $(cat $d/mem_info_gtt_total) / 1024**3 )) GiB"
done
```

About 124 GiB is correct. About 62 GiB means the parameters did not take
effect. The restart also applies the `render` and `kvm` group changes.

GTT is a ceiling, not a reservation. What the model actually holds is decided
by the model and its context, below.

### Install the model

The default model is Qwen3.8 27B (dense, 17.6 GB). Qwen3.8-Flash-Next, which
ai-server runs, needs 111 GB and does not fit beside the sandboxes. See the
memory budget in [docs/ai-workstation.md](../../docs/ai-workstation.md).

```console
ai-model add unsloth/Qwen3.8-27B-GGUF '*UD-Q4_K_XL*'
```

`ai-model add` re-runs `20_llama`, which starts the server with two slots
(`$AI_WORKSTATION_PARALLEL`). The context is per request, and the server
reserves it once for each slot.

### Join the overlay network

`25_network` needs a setup key, which is a secret and is not in this
repository, so it is the one step a plain `setup` skips. In the NetBird
dashboard, make an `ai-workstation` group, then take a one-off key that
auto-assigns it. Name the peer `aiws`:

```console
ai-workstation set overlay_hostname aiws
NETBIRD_SETUP_KEY='<key>' setup 25_network
```

The dashboard policy that lets a client reach the `ai-workstation` group must
allow **TCP port 22 and the model port (8080)**. NetBird drops traffic to a
port that the policy does not allow, so without port 22 the model server
answers but `ssh` to the overlay address hangs at `Connecting to … port 22`
with no error.

### Read the model API key

`20_llama` made the key, and only root can read it:

```console
sudo sed -n 's/^LLAMA_SWAP_API_KEY=//p' /etc/llama-swap/api-key.env
```

Every client needs it: the sandboxes on this machine (below), and `pi-ailo` on
any other machine that uses this server. To replace it, delete the file, run
`setup 20_llama`, and give the new key to every client.

### Set up sbx

These need a person, because each one is a login or a secret.

1. **Sign in.**

   ```console
   sbx login
   ```

2. **Check that secrets can be stored.** The `docker-sbx` package depends on
   `gnome-keyring`, and an SSH session on a headless machine has no keyring
   unlocked. **Not yet verified.** If `sbx secret set` fails with a D-Bus or
   keyring error, run the commands below inside a session that has one:

   ```console
   dbus-run-session -- bash
   echo -n '<a new keyring password>' | gnome-keyring-daemon --unlock
   ```

   Record the result in [docs/ai-workstation.md](../../docs/ai-workstation.md).

3. **Give the agents a GitHub token.** Make a fine-grained personal access
   token on GitHub:
   - Repository access: only the repositories this machine works on.
   - Permissions: Contents (read and write) and Pull requests (read and
     write). Nothing else.
   - Expiry: 90 days. Put the renewal date in your calendar.

   On each of those repositories, protect `main` (require a pull request
   before merging), so that merges stay with a person.

   ```console
   sbx secret set github -t '<token>'
   ```

   Not `gh auth token`: that token reaches every repository you have.

4. **Give pi the model API key.**

   ```console
   sbx secret set model-server -t '<key from above>'
   ```

5. **Point pi at this machine.**

   ```console
   mkdir -p ~/.config/sbx
   printf 'modelHost=%s\n' host.docker.internal >~/.config/sbx/kit.args
   ```

6. **Prove the path from a sandbox to the model.** Start one in tmux, then
   name it to `doctor` from a second window:

   ```console
   tmux new -s agents
   cd ~/src/<project> && sbx-up pi-ailo
   # in a second tmux window:
   sbx ls
   AI_WORKSTATION_PROBE_SANDBOX=<name> doctor
   ```

   **Not yet verified.** The sbx proxy may rewrite `host.docker.internal` to
   `localhost` before it checks its policy. If the check reports that the
   proxy refused the request, allow the port on the host and try again:

   ```console
   sbx policy allow network localhost:8080
   ```

   If it reports a 401 instead, the key was not added. The `pi-ailo` kit adds
   it for the host named in `modelHost`, and the rewrite may stop that match
   as well. Record what you find in
   [docs/ai-workstation.md](../../docs/ai-workstation.md).

7. **Prove the Claude subscription login.** Start `sbx-up` (the default agent
   is `my-claude`), and sign in with the subscription when Claude Code asks.
   **Not yet verified** on a Linux host.

### Configure the clients

On the laptop:

- Add a host to `~/.ssh/config`, separate from the ai-server one, because the
  two installs have different host keys:

  ```text
  Host aiws
    HostName aiws.netbird.cloud
    User <user>
  ```

- To use this model from the laptop's `pi-ailo`, set `modelHost` to the
  `aiws` overlay name in the laptop's `~/.config/sbx/kit.args`, and bind the
  same key there with `sbx secret set model-server`.

### Last, check everything

```console
doctor
```
