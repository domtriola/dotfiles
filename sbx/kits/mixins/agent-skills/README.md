# agent-skills

A v3 mixin that ships this repo's personal agent skills into the sandbox and
exposes them to whichever coding agent is running.

```console
sbx run claude --kit ./sbx/kits/mixins/agent-skills
```

## How skills get in

`env/.agents/skills/` is the one source of truth for every machine. Skills are
authored there, on the host. See
[Agent skills](../../../../README.md#agent-skills) in the root README.

`sync-skills` copies them into this kit's `skills/` directory, and writes the
kit's descriptor, `agent-skills.yaml`, from `descriptor.yaml.tmpl` with one
`agent-skill@1` entry for each skill. `sbx-up` runs it before it starts a
sandbox. Both are generated and gitignored: the kit is built from this working
tree, so there is nothing to commit and nothing that can drift.

`agent-skills.dockerfile` copies the skills to `/usr/share/agent-skills/` in
the image. Before the agent starts, the runtime shows each skill in every
skills directory that the agent kit declares with `agent-skills@1`:
`~/.claude/skills/` for Claude Code, and `~/.agents/skills/` for pi. Editing a
skill in the sandbox changes nothing on the host.

Each entry is optional. The runtime does not overwrite a skill that is already
there, for example from the host's shared skills store, so it skips that skill
rather than refusing the sandbox.

## Local, untracked skills

`env/.agents/skills-local/` is a scratch area whose contents are ignored by git.
Drop a skill in and it is picked up on the next `sync-skills`, in `$HOME` on
the next `sync-env`, and in the sandbox on the next start:

```console
cp -R ../some-repo/skills/thing env/.agents/skills-local/
```

A local skill shadows a tracked skill of the same name. To promote one, move it
into `env/.agents/skills/` and commit.

A skill whose directory name the runtime refuses (it must match
`[A-Za-z0-9][A-Za-z0-9._-]*`) is left out, with a warning.

## Starting a sandbox without sbx-up

The kit is generated ahead of time, so a bare `sbx run` ships whatever
`sync-skills` wrote last. Run it by hand after editing a skill. Without it,
there is no `agent-skills.yaml`, and `sbx` cannot build the kit.

To check what arrived:

```console
sbx exec <name> -- ls /home/agent/.claude/skills
```
