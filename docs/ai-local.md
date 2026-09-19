# Local AI setup

Rough draft manual steps to set up a Framework Desktop as a local AI server.

## Installing Ubuntu as dual boot option

### Create the bootable Ubuntu USB

[Download Ubuntu Server](https://ubuntu.com/download/server)

[Verify checksum (26.04.1)](https://ubuntu.com/download/server/thank-you?version=26.04.1&architecture=amd64&lts=true)

```sh
cd ~/Downloads
echo "cc8a95cde20f6ced61a322420de00f10cc3c90ced545daa46cb9c1a117f1d927 *ubuntu-26.04.1-live-server-amd64.iso" | shasum -a 256 --check
```

On MacOS use [balenaEtcher](https://etcher.balena.io/) to create a bootable USB from the iso:

1. Flash from file: ubuntu iso
1. Select target: USB
1. Flash!

### Install Ubuntu on Framework

NOTE: connect an ethernet cable first. This will help the installer with networking configurations at installation time.

1. Plug in USB to computer and reboot
1. Hold F12 for Framework desktop to enter boot page
1. Choose bootable USB
1. Go through install steps
1. On "installation complete" page, remove USB, then reboot

## Configure for connectivity

### Network

[Ubuntu networking docs](https://ubuntu.com/server/docs/#networking)

1. Connect ethernet cable (easiest way to reach network)
1. Set up ssh

```sh
sudo apt update
sudo apt install -y openssh-server
ip -br a
# Note IPv6 /64 address starting in 2 (not the fe80 one)
```

From dev machine:

```sh
ssh <user>@<ipv6-address>
```

Enable IPv4 if it doesn't already exist

```sh
ip -br a show scope global
# Shows /24 IP address for IPv4
```

If no IPv4:

```sh
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
# Verify ssh connection from dev machine still works before accepting
```

```sh
# Update and reboot
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

```sh
# Re-check IPv4 connection from dev machine:
ssh <user>@<ipv4-address>
```

### Security

[Ubuntu security docs](https://ubuntu.com/server/docs/#security)

#### Update all packages

```sh
sudo apt update && sudo apt full-upgrade -y
# Reboot if kernel upgrade prompts for it
sudo reboot
```

#### Prefer SSH-key only auth

[Ubuntu openssh-server docs](https://ubuntu.com/server/docs/how-to/security/openssh-server/)

Check if server already has your authorized key and proceed if not:

```sh
cat ~/.ssh/authorized_keys
```

If you already have a key (`ls ~/.ssh/*.pub`) use that. Otherwise generate one: `ssh-keygen -t ed25519 -C "dev-mac"`.

Copy the key to the server: `ssh-copy-id <user>@<framework-ipv4>`

Double check that the key works with password auth disabled: `ssh -o PasswordAuthentication=no <user>@<framework-ipv4>`

Disable password auth:

```sh
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF

sudo sshd -t && sudo systemctl restart ssh.service

# Should all read "no" now:
sudo sshd -T | grep -iE 'passwordauth|kbdinteractive|permitrootlogin'

# In new window verify you can still connect:
ssh <user>@<framework-ipv4>
```

## Optimize machine as a LLM server

[Increase VRAM max allocation](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html#memory-settings)

```sh
sudo apt install pipx
pipx ensurepath

pipx install amd-debug-tools

# View current shared memory config
amd-ttm

amd-ttm --set 96

# Reboot to apply changes
sudo reboot
```
