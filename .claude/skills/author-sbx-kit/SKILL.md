---
name: author-sbx-kit
description: Write Docker Sandboxes kits (workloads and mixins) in the v3 format. Points at the live spec documentation, and records the local conventions and engine behaviors that the documentation does not cover.
---

# Author Kit

A v3 kit is one OCI image. Its descriptor, `<name>/<name>.yaml`, starts with
`# syntax=docker/sandbox-kit:3` and declares the kit. Its recipe,
`<name>/<name>.dockerfile`, builds the content. There are two kinds:
`kind: workload` is the whole environment (the image the sandbox boots), and
`kind: mixin` is an overlay composed onto a workload with `--kit`. `sbx`
builds a local kit with Buildx when it creates a sandbox.

**Kits are a new and fast-moving feature. Read the live documentation before you
answer anything about the schema. Field names, capabilities, and validation
rules change between releases, so do not answer from memory and do not treat
this file as a substitute.**

## Sources of truth, in order

1. **SPEC-v3**, normative for the grammar:
   <https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md>
2. **Capability pages**, one per capability type, normative for its config and
   runtime behavior:
   <https://github.com/docker/sandbox-kit-spec/tree/main/docs/spec/capabilities/com.docker.sandbox>
3. **Docker's docs** for the product surface (`sbx` flags, kit args, which
   capabilities `sbx` supports): <https://docs.docker.com/ai/sandboxes/customize/>
4. **Working v3 kits to copy from**, on the `v3` branch:
   <https://github.com/docker/sbx-kits-contrib/tree/v3>
5. **A published kit's descriptor**: the `vnd.docker.sandbox.kit.descriptor`
   annotation on its image manifest.

## Local conventions

- Every image that a kit builds on, and the workload that `sbx-up` runs, is
  pinned by version tag and digest (`name:tag@sha256:...`). Renovate moves the
  two together.
- A mixin's overlay is `FROM scratch`. COPY creates parent directories owned by
  root, so a file that the overlay adds goes outside `/home/agent`. Otherwise
  the overlay takes `$HOME` away from the agent user.
- A hook declares every variable it reads in `env:`. Kit settings are `args`
  with `env:`, not static environment variables.
- Agent instructions that must load in every session do not go in
  `agent-context`, which a mixin's agent reads only on demand. `my-claude`
  uses Claude Code's managed memory, `/etc/claude-code/CLAUDE.md`.
- In v3, the proxy injects a host secret only for a service that a kit
  declares with `credential@1`. Each domain that a credential injects into
  must also be in the kit's `network-policy@1` allow list.
