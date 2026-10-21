# Framework Desktop: firmware and drives

The Framework Desktop has two drives, each with its own profile. This page holds what both bootstraps share: the firmware settings, which are for the whole machine, and the identity of each drive. [`profiles/agent-server/bootstrap.md`](../profiles/agent-server/bootstrap.md) and [`profiles/ai-server/bootstrap.md`](../profiles/ai-server/bootstrap.md) link here and do not repeat it.

## Drives

| Drive | Profile | Hostname | NetBird peer | SSH alias on the Mac | Starts |
| ----- | ------- | -------- | ------------ | -------------------- | ------ |
| 1 | `agent-server` | `doms-agents` | `doms-agents` | `doms-agents` | by default |
| 2 | `ai-server` | `ailo` | `ailo` | `ailo` | from the F12 boot menu |

Both drives use the same network card, so they can get the same LAN address. Each alias has its own `HostKeyAlias`, so SSH does not warn about a changed host key when you change drives. The aliases are in `~/.ssh/config.d/hosts` on the Mac, which is not in this repository, because it holds the addresses.

To start drive 2, tap **F12** while the Framework logo shows, and select its boot entry. The next restart starts drive 1 again.

## Firmware settings

These settings apply to both drives. When the two profiles need different settings, `agent-server` wins.

| Setting | Value | Why |
| ------- | ----- | --- |
| BIOS version | 3.06 or later | 3.06 lets F2 in the F12 boot menu open the full setup. Update it through LVFS (`fwupdmgr`). |
| Boot order | drive 1 first, then drive 2 | An unattended restart (after a power cut) starts `agent-server`. |
| iGPU Memory Configuration | **Auto** (a 512 MiB carve-out) | `agent-server` does not use the GPU. `ai-server` gives the GPU its memory through kernel parameters (GTT), so the minimum carve-out is correct for it too. |
| SVM | on | `sbx` runs each sandbox in a VM through KVM. It is on by default. |
| Power On AC Attach | Enabled | The box starts by itself when the power comes back. It then waits at the LUKS prompt of drive 1. |

Each drive sets its own kernel command line, which is not a firmware setting. `ai-server` turns the IOMMU off for the GPU. `agent-server` never does, so that a device on a USB4 port cannot read the memory of the running box.

### Set the boot order

From drive 1, find its boot entry. It is the entry whose `HD(...)` holds the `PARTUUID` of the partition mounted at `/boot/efi`:

```console
sudo efibootmgr -v
lsblk -o NAME,PARTUUID,MOUNTPOINTS
```

Put drive 1 first and drive 2 second, and keep the other entries after them:

```console
sudo efibootmgr -o <drive-1 entry>,<drive-2 entry>,<the other entries>
```

### Change a setting in the firmware setup

Run `sudo systemctl reboot --firmware-setup`, or tap **F2** while the Framework logo shows. A Bluetooth keyboard does not work there. In **Setup Utility**, the iGPU memory is on the **Advanced** tab, and **Power On AC Attach** is with the boot options. Press **F10** to save.
