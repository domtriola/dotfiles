# agent-skills

A mixin kit that ships this repo's personal agent skills into the sandbox.

Each tracked skill directory under `~/skills/` is symlinked into
`~/.claude/skills/`, `~/.gemini/skills/` and `~/.agents/skills/`, so whichever
agent is running sees the same skills. A directory counts as a skill only if it
contains a `SKILL.md`. These symlinks are committed under `files/home/` and land
with the rest of the sandbox's files, before any startup hook runs — this
matters because the agent CLI reads its skills directory very early, and a
symlink created by a startup hook can lose that race (see
[Why static symlinks](#why-static-symlinks-for-tracked-skills)).

Skills currently shipped: `domain-modeling`, `grill-me`, `grill-with-docs`,
`grilling`, `kit-author`, `skills-security-review`.

### Adding or removing a tracked skill

After adding a skill directory under `files/home/skills/<name>/` (or removing
one), regenerate its symlinks:

```console
cd sbx/kits/mixins/agent-skills/files/home
for agent_dir in .claude/skills .gemini/skills .agents/skills; do
  ln -sfn "../../skills/<name>" "$agent_dir/<name>"   # or: rm "$agent_dir/<name>"
done
```

Commit the resulting symlinks along with the skill directory.

## Experimental skills

`files/home/skills/experimental/` is a scratch area whose contents are ignored by
git (see the `.gitignore` inside it) but are still copied into the sandbox, since
the kit is loaded from this working tree rather than from a clean checkout. Drop a
skill in and it is picked up on the next sandbox start:

```console
cp -R ../some-repo/skills/tdd sbx/kits/mixins/agent-skills/files/home/skills/experimental/
```

Up to two levels of grouping are supported, so both
`experimental/<name>/SKILL.md` and `experimental/<vendor>/<topic>/<name>/SKILL.md`
are found. Experimental skills are still linked by a startup hook, since their
names aren't known until the sandbox boots; an experimental copy of a shipped
skill shadows it.

To promote one, move it up into `files/home/skills/` and add its symlinks (see
[Adding or removing a tracked skill](#adding-or-removing-a-tracked-skill)).

## Why static symlinks for tracked skills

This kit used to link every skill, tracked and experimental alike, from a
single startup hook. That hook runs concurrently with the agent CLI's own
startup rather than before it, and on a sandbox that also runs the (slower)
dotfiles kit, the CLI was observed reading `~/.claude/skills/` about 20
seconds before this kit's hook got a turn — so none of its skills showed up
for the session. Tracked skills are known at commit time, so they're linked as
symlinks checked into `files/home/`, which land with the rest of the
sandbox's files before any startup hook runs. Only experimental skills, whose
names are discovered at boot, still rely on the startup hook.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/agent-skills
```
