# Local AI setup

Rough draft manual steps to set up a Framework Desktop as a local AI server.

[Increase VRAM max allocation](https://rocm.docs.amd.com/en/latest/reference/system-optimization/rdna3-5.html#memory-settings)

```sh
sudo dnf install pipx
pipx ensurepath

pipx install amd-debug-tools

# View current shared memory config
amd-ttm

amd-ttm --set 96

# Reboot to apply changes
sudo reboot
```
