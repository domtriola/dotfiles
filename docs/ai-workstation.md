# AI workstation

Reference for the `ai-workstation` profile: what this machine is for, how its
memory is shared, what is still undecided, and what has not been verified yet.

To build the machine from bare metal, follow
[profiles/ai-workstation/bootstrap.md](../profiles/ai-workstation/bootstrap.md).
For what the profile installs, read `profiles/ai-workstation/`. For what a
running machine is set to, run `doctor` and `ai-workstation show`.

Much of this hardware was first learned on ai-server. The facts in
[docs/ai-server.md](ai-server.md) apply here too, because both are Ubuntu
26.04 on the same Framework Desktop.

## What it is

An always-on, headless machine where coding agents work on tasks for long
periods. It is reached over SSH through NetBird, as the `aiws` peer.

- **Claude agents** run in Docker Sandboxes (`sbx`) with the `my-claude` kit,
  on the Claude subscription, through the unmodified Claude Code client.
- **pi agents** run in sandboxes with the `pi-ailo` kit, against the model
  server on this machine.
- **The host holds no toolchains.** Languages, package managers and the code
  the agents run all stay inside the sandboxes.
- **UI work is checked on another machine**, after pulling the branch.

It lives on drive 1 of the Framework Desktop, in place of Fedora. Drive 2 keeps
the ai-server install as a cold fallback. Only one of them runs at a time.

## How the memory is shared

The machine has 128 GB of unified memory, and the GPU and the sandboxes take
from the same pool.

| Consumer                   | Budget  | Set by                                       |
| -------------------------- | ------- | -------------------------------------------- |
| Model weights and KV cache | ≤ 70 GB | The model chosen, its context, and the slots |
| Sandboxes, about 5 at once | ~40 GB  | `memory` in each project's `.sbx.json`       |
| The OS, and a margin       | ~8 GB   |                                              |

`sbx-up` gives a sandbox 4 GB unless the project's `.sbx.json` says otherwise.
A project that runs heavy builds or a browser needs `"memory": "8g"`.

**Qwen3.8-Flash-Next does not fit.** It needs 111 GB. The default model is
Qwen3.8 27B, at 17.6 GB, which leaves room to raise the context or to try a
larger model.

The server has two slots (`ai-workstation set parallel <n>`), so a second pi
agent does not wait for the first one's prefill. Each slot holds a whole
context, so the KV cache costs the context times the slots. `ai-model ctx`
reports the context per request, and the memory for all of the slots.

**When memory runs out, a sandbox is killed first.** The llama-swap unit sets
`OOMScoreAdjust=-500`. Without it, the kernel would always pick the model
server, because it holds the most memory, and every pi agent would stop.

## How the model is served

| Address                  | Who uses it                      | What answers                    |
| ------------------------ | -------------------------------- | ------------------------------- |
| `127.0.0.1:8080`         | Sandboxes, through the sbx proxy | llama-swap                      |
| `<overlay address>:8080` | Overlay peers, such as a laptop  | A socket proxy, then llama-swap |

llama-swap listens on one address, and that address is loopback, so the
sandboxes never depend on the overlay. `25_network` adds a
`systemd-socket-proxyd` socket on the overlay address. `FreeBind` lets the
socket hold that address before `wt0` exists at boot.

**Every endpoint needs the API key**, including `/v1/models` and the UI. The
key is in `/etc/llama-swap/api-key.env`, which only root can read. Read it with:

```console
sudo sed -n 's/^LLAMA_SWAP_API_KEY=//p' /etc/llama-swap/api-key.env
```

## Cleaning up

Models, sandboxes and the system share one volume. `doctor` warns at 85
percent use. Finished sandboxes are the usual cause:

```console
sbx ls
sbx rm <name>
df -h /
```

`ai-model rm <name>` removes a model that is no longer wanted.

## Undecided

### Unattended unlock

The root filesystem is encrypted with a passphrase. Every boot needs a person
at the console, so after a power cut or a manual restart the machine stays down
until someone is there. Automatic updates install, and never restart the
machine (`05_hardening`).

The options are the same as on ai-server (TPM2 through Clevis, Dropbear, or
both), and so are the facts they depend on. See
[The encrypted root cannot reboot unattended](ai-server.md#the-encrypted-root-cannot-reboot-unattended).

### A better model

A mixture-of-experts model of 40 to 70 GB, at 4 bits, could decode faster than
the dense 27B model, because decode follows active parameters. Use the review
process in
[docs/ai-server.md](ai-server.md#reviewing-models), with this machine's
weight limit of about 70 GB instead of 115 GB.

## Not yet verified

The design depends on these, and none of them could be tested before the
machine existed. Record each result here.

| Question                                                                                                            | How to find out                              | Result |
| ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------ |
| Does `host.docker.internal` reach the host's loopback from a sandbox? Does the policy need `localhost:8080`?        | `AI_WORKSTATION_PROBE_SANDBOX=<name> doctor` |        |
| Does the sbx proxy add the model key for `host.docker.internal`, or does the rewrite to `localhost` stop the match? | The same check: 200 means yes, 401 means no  |        |
| Does `sbx secret set` work over SSH on a headless machine, given the `gnome-keyring` dependency?                    | Bootstrap, "Set up sbx", step 2              |        |
| Does the Claude subscription login work inside sbx on a Linux host?                                                 | Bootstrap, "Set up sbx", step 7              |        |

Already answered: sbx does take a memory limit for each sandbox
(`sbx run --memory`), and `sbx-up` passes it.
