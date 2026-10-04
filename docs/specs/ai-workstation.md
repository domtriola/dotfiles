# Spec: the `ai-workstation` profile

## Problem Statement

I want a machine that is always on, where coding agents can work on tasks for long periods without me. Claude agents must use my Claude subscription, through Claude Code. pi agents must use a local model. The agents must also have enough memory and disk to run the applications they work on (servers, tests, builds).

The Framework Desktop has two drives. Drive 2 runs the `ai-server` profile, which is a model server only. It has no sandboxes, and its model (Qwen3.8-Flash-Next, 111 GB) uses almost all of the memory. Drive 1 runs Fedora (`dev-linux`). Docker Sandboxes does not support Fedora, and the machine can run only one operating system at a time. No current profile can do the job.

## Solution

A new profile, `ai-workstation`, on a fresh Ubuntu Server 26.04 install on drive 1. This replaces Fedora. It becomes the operating system that the machine boots by default. The ai-server drive stays bootable as a cold fallback.

The workstation is headless. It runs the model server itself, sized so that the sandboxes have room, and it runs Docker Sandboxes (`sbx`) for Claude and pi agents. I connect over SSH through NetBird, the same way I connect to ai-server. I start agents in tmux and leave them running. I check UI work on another machine, after I pull the branch.

## User Stories

1. As the owner, I want to install the workstation on drive 1 with a written bootstrap, so that I can build it from bare metal without guessing.
2. As the owner, I want the firmware to boot the workstation by default, so that a restart returns the workstation and not the fallback.
3. As the owner, I want the ai-server drive to stay bootable, so that I have a known-good model server if the workstation fails.
4. As the owner, I want to unlock the encrypted disk at the console on each boot, so that a drive taken from the machine is unreadable.
5. As the owner, I want automatic updates that never restart the machine by themselves, so that an attended unlock never strands the machine without my knowledge.
6. As the owner, I want to connect over SSH with a key only, through NetBird, so that I can reach the machine from anywhere and passwords are never accepted.
7. As the owner, I want the workstation to have its own NetBird peer (`aiws`) and group (`ai-workstation`), so that it is never confused with the ai-server install.
8. As the owner, I want the machine to never suspend, so that SSH sessions and agents survive idle periods.
9. As the owner, I want to start Claude and pi sandboxes with `sbx-up` in a tmux session, and detach, so that agents keep working after I disconnect.
10. As the owner, I want linger enabled for my user, so that logout never kills my tmux session or agents.
11. As the owner, I want Claude sandboxes to use my Claude subscription through the unmodified Claude Code client, so that the use is permitted and costs nothing extra.
12. As the owner, I want pi sandboxes to reach the local model through `host.docker.internal`, so that pi works without a network round trip.
13. As the owner, I want the model API to require a key, so that agent code that I have not reviewed, or a peer on the overlay, cannot use or control the model server without it.
14. As the owner, I want the model server to answer on loopback and on the overlay, so that sandboxes on this machine and `pi-ailo` on my laptop can both use it.
15. As the owner, I want about three Claude sandboxes and one or two pi sandboxes to run at the same time, so that several tasks progress in parallel.
16. As the owner, I want the model server to serve two requests at once, so that a second pi agent does not wait for the first prefill.
17. As the owner, I want the default model to use about 70 GB or less, including its KV cache, so that the sandboxes have about 40 GB.
18. As the owner, I want the kernel to kill a sandbox before the model server when memory runs out, so that one failure does not stop every pi agent.
19. As the owner, I want agents to push only to repositories that I assign to this machine, so that a misbehaving agent cannot change my other repositories.
20. As the owner, I want `main` to be protected on those repositories, so that merges stay with a person.
21. As the owner, I want `doctor` to warn when the disk is 85 percent full, and the docs to tell me how to clean up sandboxes, so that a full disk does not stop everything.
22. As the owner, I want the host to hold only what the machine needs (model server, sbx, tmux, neovim, shell configuration), so that agent toolchains stay behind the VM boundary.
23. As the owner, I want `ai-workstation show` and `ai-workstation set` for the machine's settings, so that I manage them the same way that I manage ai-server.
24. As the owner, I want `ai-model` to add, remove and size models, so that I can test a better model next to the current one.
25. As the owner, I want `doctor` to report the real state of every part (SSH, firewall, GPU, model server, sandboxes, storage, overlay, updates), so that faults that do not show an error are still found.

## Implementation Decisions

**Profile.** `ai-workstation` is a new profile with its own directory. Profiles share no scripts, so it gets its own copies of the ai-server setup steps. In the copies, the `ai-server` name becomes `ai-workstation`. This includes the profile command (`ai-workstation`), the configuration file (`/etc/ai-workstation/config.env`) and the configuration helpers. `ai-model` keeps its name.

**Setup steps.** They are copied from ai-server, in the same order, with these changes:

- **Preflight** asks the same questions (the IOMMU setting, and whether to extend the root logical volume).
- **Hardening** is the same as ai-server: SSH with keys only, and ufw. The automatic-update configuration sets `Automatic-Reboot "false"`, and the `doctor` "Updates" section checks it. A new item masks the systemd sleep, suspend and hibernate targets.
- **Packages** is the ai-server list, plus tmux, neovim and KVM support. The user is added to the `kvm` and `render` groups. There are no language toolchains.
- **Storage** is one volume, the same as ai-server. Root gets all of the free extents. The models are not on a separate logical volume.
- **GPU** uses the same GRUB GTT parameters and tuned profile. No change.
- **Model server** is llama.cpp (Vulkan build) and llama-swap, the same as ai-server, with these changes:
  - llama-swap listens on loopback **and** on the overlay address. ai-server listens on the overlay only.
  - llama-swap requires a key from `apiKeys`. The key is a secret, so it is not stored in the repository. Setup takes it the way `25_network` takes the NetBird setup key.
  - The llama-swap unit sets a negative `OOMScoreAdjust`, so that the kernel kills a sandbox before the model server.
  - The default model is Qwen3.8 27B (dense, 17.6 GB). It runs with `--parallel 2`, and its context is set explicitly (not the model's maximum).
- **Sandboxes** is a new setup step. It installs `docker-sbx` from Docker's apt repository and enables linger for the user.
- **Network** installs NetBird with no UI and joins the `ai-workstation` group. ufw allows the model port on `wt0`.
- **Tools** installs `ai-model` and the `ai-workstation` command.

**Environment manifest.** It includes the shared commands (`setup`, `sync-env`, `doctor`), the shell configuration, tmux and neovim configuration, `sbx-up`, `sbx-pull` and the Claude settings that `my-claude` uses.

**Memory budget.** The machine has 128 GB of unified memory. About 40 GB goes to sandboxes (about 8 GB each), about 8 GB to the OS and a margin, and about 70 GB or less to model weights plus KV cache. Qwen3.8-Flash-Next does not fit in this budget.

**Kits.** `my-claude` needs no change. `pi-ailo` needs no structural change: `modelHost` is already an argument. On the workstation, `modelHost` is `host.docker.internal`. On the laptop, it is the `aiws` overlay name. `pi-ailo` has to send the model API key, as a kit credential.

**Credentials.** The GitHub secret in sbx is a fine-grained PAT, limited to the chosen repositories, with contents and pull-request permissions only, and a 90-day expiry. Claude uses the subscription login that the upstream `claude` kit supports.

**Firmware.** `efibootmgr` puts the workstation first and ai-server second.

**Docs.**
- A workstation bootstrap, adapted from the ai-server bootstrap. It covers the drive choice, the attended LUKS unlock, the boot order, the NetBird policy (port 22 and the model port) and the PAT.
- A `docs/ai-workstation.md` reference, with the memory budget, the open decisions and the cleanup command.
- A row in the README profile table.
- In `docs/ai-server.md`, the question "What happens to Fedora on drive 1" is closed, and the "no authentication" item points to the workstation's key.

## Testing Decisions

**Seam: `doctor` only.** The profile's checks run against the live machine. A good check reads the real value (`sshd -T`, the driver name, the GTT total, the reply to a real request) and reports what it found. It does not only check that a file exists. Most faults on this hardware fail without an error.

The workstation's doctor checks keep every ai-server section (SSH, Firewall, Network, GPU memory, GPU access, Performance profile, Model server, Storage, Overlay network, Updates, Tunables), adapted to the new names. They add these checks:

- **Sandboxes**: `sbx` is installed, the user is in `kvm`, and linger is enabled.
- **Sandbox to model**: a request from a sandbox to `host.docker.internal` reaches llama-swap.
- **Model API key**: a request with no key is refused, and a request with the key succeeds, on loopback and on the overlay.
- **Model server**: the llama-swap unit has the expected `OOMScoreAdjust`, and llama-swap listens on loopback and on the overlay.
- **Storage**: `doctor` warns at 85 percent use.
- **Updates**: automatic updates never reboot the machine.
- **Power**: the sleep targets are masked.

`setup --profile ai-workstation --dry` previews the steps, the same as for other profiles. There is no new test harness.

Prior art: the ai-server profile's `lib/doctor.sh`.

## Out of Scope

- Task orchestration, a task queue, notifications when agents finish or stop, and dashboards.
- A desktop environment, remote desktop and GUI testing on the machine.
- Unattended reboot (TPM2, Clevis or Dropbear). The decision is deferred.
- Choosing a mixture-of-experts model of 40 to 70 GB. This is a follow-up task that uses the review process in `docs/ai-server.md`.
- Retiring or reusing the ai-server drive, and dual-drive striping.
- Language toolchains on the host.
- TLS for the overlay.

## Further Notes

**Verify these during the build.** They are not confirmed, and the design depends on them:

- That `host.docker.internal` reaches the host's loopback from an sbx sandbox on a Linux host. The sbx proxy may rewrite the name to `localhost` before it checks the policy, so the allow rule may have to name `localhost:8080`, not `host.docker.internal:8080`.
- That sbx lets you set a memory limit for each VM. If it does not, the 8 GB budget for each sandbox becomes an estimate, and the OOM order is the only protection.
- That the Claude subscription login works inside sbx on Linux.

**Known costs of the decisions.**

- With an attended LUKS unlock, the machine stays down after a power cut or a manual restart until a person is at the console.
- Two pi agents share one GPU. With `--parallel 2`, a second request does not wait for the first, but each request is slower. Prefill is about 400 to 560 tok/s on the models measured so far.
- Each switch between models costs 20 to 30 seconds in each direction, so all pi agents should use the same model.
