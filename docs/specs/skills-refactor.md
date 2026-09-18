Phase 0 (gate): test whether kit files survive under ~/.claude

Everything downstream has one unverified assumption: your own note in my-claude/spec.yaml says the runtime discards a kit file at ~/.claude/settings.json, and nobody knows whether that applies to the whole directory.

On the host, add one throwaway file to the existing kit, start a sandbox, and look:

mkdir -p sbx/kits/mixins/agent-skills/files/home/.claude/skills/probe
printf -- '---\nname: probe\ndescription: probe\n---\nprobe\n' \

> sbx/kits/mixins/agent-skills/files/home/.claude/skills/probe/SKILL.md
> sbx-up # then, in the sandbox: ls ~/.claude/skills/probe

┌───────────────────┬───────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Result │ Shape │ Effect on the plan │
├───────────────────┼───────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ The file is there │ A │ The mirror writes straight to files/home/.claude/skills/ and files/home/.agents/skills/. No hooks at all. │
├───────────────────┼───────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ The file is gone │ B │ The mirror writes to files/home/skills/ only, and a setup.install hook copies it into both directories (install is guaranteed to run before the entrypoint). │
└───────────────────┴───────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

Write sync-skills (Phase 3) with both layouts behind one variable, so the outcome here is a one-line change and not a rewrite. Delete the probe afterwards.

Phase 1: move the source of truth into env/.agents/skills

1. git mv the seven tracked skills from sbx/kits/mixins/agent-skills/files/home/skills/ to env/.agents/skills/: agent-init, domain-modeling, grill-me, grill-with-docs, grilling, kit-author, skills-security-review.
2. Create env/.agents/skills-local/.gitignore with the same two-line trick the experimental/ directory uses (* plus !.gitignore). The directory stays tracked, its contents do not. This replaces experimental/ as the scratch area, and it is now flat (no vendor or topic grouping), because the mirror no longer searches for SKILL.md at arbitrary depth.
3. git rm -r the old experimental/ directory, including its .gitignore.

One decision to make here. The 33 mattpocock skills currently live in that untracked experimental/ tree, so they disappear at this step and come back in Phase 2 as tracked, pinned, vendored copies. I would vendor engineering/* and productivity/* (the ones you actually invoke), leave in-progress/* out because it is explicitly unfinished, and leave misc/* out because those are repo-specific (scaffold-exercises, migrate-to-shoehorn). Tell me if you want a different cut and I will change the skills.json in Phase 2.

Phase 2: ./pull-skills, the refresh verb

Two new files plus one script.

env/.agents/skills.json, hand-edited, one entry per upstream:

[
{
"repo": "https://github.com/mattpocock/skills",
"ref": "main",
"paths": ["engineering/_", "productivity/_"],
"exclude": ["engineering/setup-matt-pocock-skills"],
"rename": { "engineering/code-review": "matt-code-review" }
}
]

A glob keeps the file short (33 skills would be unreadable as an explicit map). The destination name is the basename of the matched directory unless rename says otherwise.

env/.agents/skills.lock, written by the script, never hand-edited: for each vendored skill, the repo, the ref, the resolved commit SHA, the source path, and a checksum of the copied tree.

./pull-skills [--dry] [--only <repo>] does:

1. For each entry, git clone --depth 1 --branch <ref> into a temp directory (mktemp -d, cleaned up with a trap).
2. Expand paths, apply exclude, apply rename, and reject any directory with no SKILL.md and any duplicate destination name (across all sources, not just within one). A collision is a hard error, since rename exists to resolve it.
3. Before overwriting, compare each existing destination against the checksum in the lock. If they differ, the skill was edited locally: print the names and stop, unless --force is passed. This is the one failure mode vendoring has, so it gets an explicit guard.
4. rm -rf then copy each skill into env/.agents/skills/<dest>. Delete any skill that the lock lists but skills.json no longer selects.
5. Rewrite skills.lock, then print the changed skill names and remind you to read git diff before committing.

Follow the conventions of the existing scripts: set -eo pipefail, the log/execute/--dry pair copied from sync-env, and a usage comment at the top.

Your own skills and the vendored ones share the flat directory, and the lock file is what tells them apart. That keeps the destination mapping trivial (one directory copies to one directory) at the cost of needing the lock to know provenance, which is the right trade here.

Phase 3: ./sync-skills, the mirror verb

./sync-skills [--dry] regenerates the kit payload from env/.agents/:

1. rm -rf the generated directories under sbx/kits/mixins/agent-skills/files/.
2. Copy env/.agents/skills/* into each destination for the shape chosen in Phase 0 (shape A: files/home/.claude/skills/ and files/home/.agents/skills/; shape B: files/home/skills/ only).
3. Overlay env/.agents/skills-local/* on top, so a local copy still shadows a tracked skill of the same name.
4. Skip any directory with no SKILL.md, and skip dotfiles such as .gitignore.

Then add to .gitignore:

# Generated by ./sync-skills from env/.agents/. The kit loads from the working

# tree, so this is built rather than committed.

sbx/kits/mixins/agent-skills/files/

And to .prettierignore, the same path plus env/.agents/skills.lock, so a refresh does not produce reformatting noise.

Wire it into env/.local/bin/sbx-up, just before the sbx rm call:

if [[ -x "$dotfiles/sync-skills" ]]; then
"$dotfiles/sync-skills" >/dev/null || {
printf 'sbx-up: sync-skills failed; the sandbox will have stale skills\n' >&2
}
fi

It warns instead of aborting, because a stale skill set is better than no sandbox. Remember that sbx-up is installed by ./sync-env, so this change needs a ./sync-env run on the host before it takes effect.

Phase 4: feed $HOME on real machines

In setups/dev-mac/env.manifest and setups/dev-linux/env.manifest, extend the existing group Claude settings block:

dir .agents/skills $HOME/.claude/skills
dir     .agents/skills       $HOME/.agents/skills
subdirs .agents/skills-local $HOME/.claude/skills
subdirs .agents/skills-local $HOME/.agents/skills

dir wipes the destination first, so a deleted skill really disappears. subdirs runs second and only adds, which preserves the shadowing rule.

Leave setups/infosec-qubes/env.manifest alone (that profile deliberately ships no agent settings).

Leave setups/sbx-linux/env.manifest alone too, deliberately. Inside a sandbox, sync-env runs from the dotfiles startup hook about twenty seconds after the agent starts, and a dir directive does rm -rf before it copies. Adding skills there would delete the skills directory out from under a running agent. In a sandbox the kit owns skills; on a real machine sync-env does. This is worth a comment in the manifest so it is not "fixed" later.

Phase 5: delete the symlink hook

In sbx/kits/mixins/agent-skills/spec.yaml:

- Remove the whole setup.startup block.
- Shape B only: add the setup.install copy in its place, with user: "1000" so it does not write root-owned files into /home/agent.
- Optionally add a small install guard that fails loudly when the skills directory is empty, which catches a sandbox started without sbx-up having run the mirror.
- Rewrite agentInstructions: skills are real directories at ~/.claude/skills/ and ~/.agents/skills/, they are copies and not symlinks, and editing one inside the sandbox changes nothing permanent (the dotfiles clone there is shallow and detached, so skills are authored in the dotfiles repo on the host).

Revert .sbx.json to ["dotfiles", "agent-skills"] if you like. The ordering workaround from commit 46f4639 no longer does anything once no hook is involved, and leaving it in place suggests a constraint that does not exist.

Note that /Users/dominicktriola/src/personal/kits-agent-context/agent-skills.md is generated by the engine from agentInstructions, so it refreshes on the next sandbox start. There is nothing to edit by hand.

Phase 6: documentation

- Rewrite sbx/kits/mixins/agent-skills/README.md: the kit now ships a generated payload, the source is env/.agents/skills, and there is no symlink step.
- Add a short section to the top-level README.md next to the ./sync-env and ./setup description, covering the three verbs and when each one runs.
- Mention in pull-skills's usage comment that vendored skills are third-party agent instructions, and that git diff plus the skills-security-review skill is the review step before committing.

Phase 7: verification

1. ./pull-skills --dry, then a real run, then read the diff and commit.
2. HOME=/tmp/fakehome ./sync-env --profile dev-mac (the fake-home trick already documented in sync-env), and check both skills directories, including that a skills-local entry shadows a tracked one.
3. ./sync-skills, then confirm the kit payload matches, then git status to confirm nothing generated is tracked.
4. sbx-up in this repo, and confirm the skills are listed in the agent's first turn. That is the actual race test, so repeat it a few times, and once with .sbx.json back in ["dotfiles", "agent-skills"] order, which is the arrangement that used to lose.
5. sbx exec <name> -- ls /home/agent/.claude/skills from the host, to confirm real directories rather than symlinks.

Suggested commit split: (1) move skills to env/.agents/, (2) add pull-skills and vendor the mattpocock set, (3) add sync-skills and wire up sbx-up, (4) manifests, (5) drop the symlink hook, (6) docs. Each one leaves the repo working, and the race stays fixed from commit 5 onward.
