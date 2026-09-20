# AI server: manual bootstrap

Every step from a bare Framework Desktop to the point where the `ai-server`
profile can run. This is the source of truth for those steps.

Nothing here is scripted, and each step says why. Everything after the last
step is done by `setups/ai-server/`.

Unresolved choices are in [ai-server-decisions.md](ai-server-decisions.md).
Step 2 meets the first of them.

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

## 2. Install Ubuntu

**Connect an Ethernet cable before starting the installer.** The installer
writes the network configuration it observes. With no carrier it writes no
`dhcp4` key, and the installed machine then comes up with IPv6 only, which
step 5 has to repair by hand.

1. Insert the USB drive and restart the machine.
2. Hold **F12** during start to reach the Framework boot menu.
3. Start the USB drive.
4. Work through the installer. Two answers matter more than the rest:
   - **Which disk.** Record the model and serial number of the target drive
     first, with `lsblk -o NAME,SIZE,MODEL,SERIAL`. Use manual partitioning,
     select only that drive, and let the installer make a new EFI system
     partition on it. A second EFI partition keeps a failed install from
     stopping the other operating system on the machine from starting.
   - **Whether to encrypt the disk.** This decides whether the machine can
     restart without a person at the console. Read decision 1 in
     [ai-server-decisions.md](ai-server-decisions.md) before answering.
5. On the "installation complete" screen, remove the USB drive, then restart.

## 3. Set the boot order

The machine should start as the server by default, so that an unattended
restart returns a server rather than something else.

Set the order in the Framework firmware setup, or from the installed system:

```console
sudo efibootmgr                     # note the entry numbers
sudo efibootmgr -o <ubuntu>,<other> # ubuntu first
```

## 4. Claim the rest of the disk

The Ubuntu Server installer builds an LVM volume group across the whole drive
and then gives the root volume about 100 GB. The remainder stays unallocated in
the volume group, so a 1 TB disk presents as a 98 GB filesystem.

This matters here more than on most servers. One model is 20 to 400 GB, so the
default leaves the machine unable to hold what it exists to serve.

```console
sudo vgs    # VFree is what was never handed out
sudo lvs    # LSize of the root volume
```

`12_storage` does this during `./setup`, and asks first. Run it by hand only
to do it before then, or to answer differently:

```console
sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
df -h /
```

`-r` grows the filesystem in the same step, and both ext4 and XFS do that
online.

LUKS sits below the volume group, so an encrypted install needs nothing extra.

The script takes all of the free extents, set by `$AI_SERVER_LV_FREE_PCT`.

**One volume holds everything**: the system, its packages, the logs, and the
models. There is no separate allocation for models, and a download large
enough to fill the disk affects the whole machine.

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

## 6. Install the SSH server

```console
sudo apt update
sudo apt install -y openssh-server git
ip -br a show scope global
```

Note the address. Connect from the client to confirm it answers:

```console
ssh <user>@<address>
```

Ubuntu Server does not always include `git`, and step 8 needs it to clone the
repository before `10_packages` can install anything.

This step is manual because `05_hardening` turns password authentication off,
and there has to be a working way in before that happens.

## 7. Copy an SSH key from the client

Run this **on the client**, while password authentication still works:

```console
ssh-copy-id <user>@<server-address>
```

Then prove that the key alone is enough, in a second terminal, keeping the
first one open:

```console
ssh -o PasswordAuthentication=no <user>@<server-address>
```

This step is manual because it runs on the client and not on the server.

`05_hardening` stops when `~/.ssh/authorized_keys` is empty, so a missed step
here fails loudly rather than locking the machine.

## 8. Clone the repository and run the profile

```console
mkdir -p ~/src/personal && cd ~/src/personal
git clone https://github.com/domtriola/dotfiles.git
cd dotfiles
./setup --profile ai-server --dry
./setup
```

Name the profile once. It is saved, and later runs reuse it.

Run `--dry` first. The real run installs packages and rebuilds the boot
configuration.

`15_gpu` asks which IOMMU setting to use, and explains both. Set
`$AI_SERVER_IOMMU` to `off` or `pt` to answer without being asked.

## What happens next

`./setup` reports when the kernel parameters change. Restart then, and confirm
that the GPU has the memory it was given:

```console
for d in /sys/class/drm/card*/device; do
  [ -f "$d/mem_info_gtt_total" ] && echo "GTT: $(( $(cat $d/mem_info_gtt_total) / 1024**3 )) GiB"
done
```

About 124 GiB is correct. About 62 GiB means the parameters did not take
effect.

Run `./sync-env` to pull environment configs.
