# agent-skills

A mixin kit that ships this repo's personal agent skills into the sandbox and
exposes them to whichever coding agent is running.

```console
sbx run claude --kit ./sbx/kits/mixins/agent-skills
```

## How skills get in

`env/.agents/skills/` is the one source of truth for every machine. Skills are
authored there, on the host, or vendored there by `./pull-skills`. See
[Agent skills](../../../../README.md#agent-skills) in the root README.

`./sync-skills` copies them into this kit's `files/` tree, and `sbx-up` runs it
before it starts a sandbox. The payload is generated and gitignored: the kit is
loaded from this working tree, so there is nothing to commit and nothing that
can drift.

Inside the sandbox the kit copies each skill into `~/.claude/skills/` and
`~/.agents/skills/` before the agent starts. They are real directories, so
editing one in the sandbox changes nothing on the host. A second hook restores
any skill that is missing after a restart. See the comments in `spec.yaml` for
why the two hooks differ.

## Local, untracked skills

`env/.agents/skills-local/` is a scratch area whose contents are ignored by git.
Drop a skill in and it is picked up on the next `./sync-skills`, in `$HOME` on
the next `./sync-env`, and in the sandbox on the next start:

```console
cp -R ../some-repo/skills/thing env/.agents/skills-local/
```

Local skills are copied after the tracked ones, so a local copy of a tracked
skill shadows it. To promote one, move it into `env/.agents/skills/` and commit.

## Starting a sandbox without sbx-up

The payload is built ahead of time, so a bare `sbx run` ships whatever
`./sync-skills` wrote last. Run it by hand after editing a skill.

If the payload is missing entirely, the sandbox still comes up, with no skills
and a note in the log. To check what arrived:

```console
sbx exec <name> -- ls /home/agent/.claude/skills
```
