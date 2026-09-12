---
name: kit-author
description: Write Docker Sandboxes kits (agents and mixins). Points at the live spec documentation, and records the local conventions and engine behaviors that the documentation does not cover.
---

# Kit Author

A kit is a `spec.yaml` plus an optional `files/` tree, which the
`sbx` engine turns into container customizations when a sandbox is created or when
`kit add` runs. There are two kinds: `kind: sandbox` is a full agent, and
`kind: mixin` is composed onto an agent with `--kit`.

**Kits are a new and fast-moving feature. Read the live documentation before you
answer anything about the schema. Field names, sections, and validation rules change
between releases, so do not answer from memory and do not treat this file as a
substitute.**

## Sources of truth, in order

1. **Official documentation**: <https://docs.docker.com/ai/sandboxes/customize/kits/>
2. **Go types**, authoritative on every field name, type, and required or optional
   rule: <https://github.com/docker/sbx-kits-contrib/blob/main/spec/types.go>
3. **Grammar reference for `schemaVersion: "2"`**:
   <https://github.com/docker/sbx-kits-contrib/blob/main/spec/SPEC-v2.md>
4. **Roughly fifty working kits to copy from**:
   <https://github.com/docker/sbx-kits-contrib>
5. **The TCK**, the conformance suite, if you want to test a kit:
   <https://github.com/docker/sbx-kits-contrib/tree/main/tck>

## Local conventions

### The `files/` tree is rooted at `/`, but `home/` means the agent's home

`files/<path>` is copied to `/<path>` in the container, with one twist: the
top-level `home/` directory maps onto the agent user's home directory, which is
`/home/agent`. So write `files/home/.config/foo/bar.json` to land
`/home/agent/.config/foo/bar.json`. Adding the `agent/` segment yourself
(`files/home/agent/...`) silently produces `/home/agent/agent/...` — the kit
installs without error and the files simply are not where anything looks for
them.
