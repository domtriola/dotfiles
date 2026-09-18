# Skills refactor

One source of truth for agent skills, no symlinks, and no race between the
agent starting and the skills appearing.

Destinations are `~/.claude/skills` and `~/.agents/skills`. Nothing writes to
`~/.gemini` any more.

## Progress

| Phase | What                                         | Status                                             |
| ----- | -------------------------------------------- | -------------------------------------------------- |
| 0     | Gate: do kit files survive under `~/.claude`  | **Waiting on the host.** Optional: it only decides whether the two hooks can go |
| 1     | Source of truth in `env/.agents/skills`      | Done. 27 skills (24 vendored, 3 original)          |
| 2     | `./pull-skills`, the refresh verb            | Done. Idempotent, drift guard and prune both tested |
| 3     | `./sync-skills`, the mirror verb             | Done. Wired into `sbx-up`                          |
| 4     | Feed `$HOME` on real machines                | Done. Verified against a fake home on `dev-linux`  |
| 5     | Delete the symlink hook                      | Done. `install` copy plus a gap-filling `startup`  |
| 6     | Documentation                                | Done                                               |
| 7     | Verification                                 | Steps 1 to 3 done in the sandbox; 4 and 5 need the host |

Still to do on the host: start a sandbox with `sbx-up` and confirm the skills
are listed in the agent's first turn (verification steps 4 and 5), then run the
phase 0 probe if the two hooks are worth deleting.

Not committed. The commit split at the end of this file still applies.

## Three verbs

| Verb        | Script          | Network | When                                   |
| ----------- | --------------- | ------- | -------------------------------------- |
| **refresh** | `./pull-skills` | yes     | manual, rarely (bump a pinned upstream) |
| **mirror**  | `./sync-skills` | no      | before `sbx up` (feeds the kit)        |
| **install** | `./sync-env`    | no      | on every machine (feeds `$HOME`)       |

Refresh must never fold into the other two. Fetching third-party agent
instructions on every sandbox start means new instructions arrive without being
read, and `skills-security-review` assumes the opposite posture.

## Findings from implementation

- **Four of the seven tracked skills were already vendored from mattpocock**
  (`domain-modeling`, `grill-with-docs`, `grilling`, `grill-me`), each with a
  hand-written `README.md` naming the source. Only `agent-init`, `kit-author`
  and `skills-security-review` are original. The four are re-vendored by
  `pull-skills`, and `skills.lock` replaces the README notes.
- **Prettier rewrites vendored markdown** (`_italic_` becomes `*italic*` in
  `domain-modeling`), which would read as a local edit on every refresh and trip
  the checksum guard. `env/.agents/` is therefore prettier-ignored.
- **Neither hook shape is verified yet.** Phase 0 asks whether kit files survive
  under `~/.claude`, but there is a second unknown: the spec does not pin whether
  `files/` is copied before `setup.install` runs. The shipped arrangement
  (install copy plus an idempotent startup repeat) is safe under every
  combination, and Phase 0 only decides whether both hooks can be deleted.

## Phase 0 (gate): test whether kit files survive under `~/.claude`

`my-claude/spec.yaml` records that the runtime discards a kit file at
`~/.claude/settings.json`. Nobody knows whether that applies to the whole
directory. On the host:

```console
mkdir -p sbx/kits/mixins/agent-skills/files/home/.claude/skills/probe
printf -- '---\nname: probe\ndescription: probe\n---\nprobe\n' \
  > sbx/kits/mixins/agent-skills/files/home/.claude/skills/probe/SKILL.md
sbx-up   # then, in the sandbox: ls ~/.claude/skills/probe
```

| Result            | Shape | Effect                                                                                       |
| ----------------- | ----- | -------------------------------------------------------------------------------------------- |
| The file is there | A     | The mirror can write straight to `files/home/.claude/skills/`, and both hooks can be deleted. |
| The file is gone  | B     | Keep the payload at `files/home/skills/` and keep the copy hooks.                             |

`sync-skills` has a `LAYOUT` variable at the top, so the outcome is a one-line
change either way. Delete the probe afterwards.

## Phase 1: move the source of truth into `env/.agents/skills`

1. Move `agent-init`, `kit-author` and `skills-security-review` from
   `sbx/kits/mixins/agent-skills/files/home/skills/` to `env/.agents/skills/`.
2. Delete the four hand-vendored copies; `pull-skills` restores them.
3. Create `env/.agents/skills-local/.gitignore` with the two-line trick the old
   `experimental/` directory used (`*` plus `!.gitignore`). The directory stays
   tracked, its contents do not. It replaces `experimental/` as the scratch
   area, and it is flat now, because the mirror no longer searches for
   `SKILL.md` at arbitrary depth.
4. Remove the old `experimental/` tree.

## Phase 2: `./pull-skills`, the refresh verb

`env/.agents/skills.json` is hand-edited, one entry per upstream. Globs keep it
short. `env/.agents/skills.lock` is written by the script and never hand-edited:
repo, ref, resolved commit, source path and a checksum for each vendored skill.

The script clones each upstream shallow into a temp directory, expands `paths`,
applies `exclude` and `rename`, rejects duplicate destination names, compares
each existing destination against its lock checksum (a mismatch means a local
edit and stops the run unless `--force` is given), copies, prunes skills the
lock lists but `skills.json` no longer selects, and rewrites the lock.

**Vendored skills are third-party agent instructions.** Read `git diff` before
committing a refresh; `skills-security-review` exists for exactly this.

## Phase 3: `./sync-skills`, the mirror verb

Regenerates the kit payload from `env/.agents/`: wipe the generated directories,
copy `env/.agents/skills/*`, overlay `env/.agents/skills-local/*` so a local copy
shadows a tracked one, and skip any directory with no `SKILL.md`.

The payload is gitignored rather than committed. It cannot drift if it is
regenerated every time, the content stays in git exactly once, and kits resolve
to a working-tree path (`sbx-up` builds `$dotfiles/sbx/kits/mixins/<name>`), so a
clean checkout is never the consumer.

`sbx-up` runs it before starting a sandbox, and warns rather than aborting when
it fails, because a stale skill set beats no sandbox. `sbx-up` is installed by
`./sync-env`, so the change needs a `./sync-env` run on the host.

## Phase 4: feed `$HOME` on real machines

`dev-mac` and `dev-linux` only. `dir` wipes the destination first, so a deleted
skill really disappears; `subdirs` runs second and only adds, which preserves the
shadowing rule.

`infosec-qubes` ships no agent settings, so it is left alone.

**`sbx-linux` is left alone deliberately.** Inside a sandbox, `sync-env` runs
from the `dotfiles` startup hook about twenty seconds after the agent starts, and
`dir` does `rm -rf` before it copies. Adding skills there would delete the skills
directory out from under a running agent. In a sandbox the kit owns skills; on a
real machine `sync-env` does.

## Phase 5: delete the symlink hook

The `setup.startup` symlink loop goes. In its place, `setup.install` copies
`~/skills/*` into both agent directories (`install` is guaranteed to run before
the entrypoint), and a small idempotent `setup.startup` repeats the copy so a
restart repairs the directory if the runtime resets it. Both run as `user:
"1000"` so nothing root-owned lands in `/home/agent`.

If Phase 0 returns shape A, both hooks can be deleted.

`agentInstructions` is rewritten: skills are real directories, they are copies
and not symlinks, and editing one inside the sandbox changes nothing permanent
(the dotfiles clone there is shallow and detached, so skills are authored in the
dotfiles repo on the host).

`kits-agent-context/agent-skills.md` is generated by the engine from
`agentInstructions`, so it refreshes on the next sandbox start.

## Phase 6: documentation

The kit README, the top-level README (the three verbs and when each runs), and a
note in `pull-skills` about reviewing vendored instructions before committing.

## Phase 7: verification

1. `./pull-skills --dry`, then a real run, then read the diff and commit.
2. `HOME=/tmp/fakehome ./sync-env --profile dev-mac`, and check both skills
   directories, including that a `skills-local` entry shadows a tracked one.
3. `./sync-skills`, then confirm the payload matches and `git status` shows
   nothing generated as tracked.
4. `sbx-up` in this repo, and confirm the skills are listed in the agent's first
   turn. Repeat a few times, and once with `.sbx.json` back in
   `["dotfiles", "agent-skills"]` order, which is the arrangement that used to
   lose.
5. `sbx exec <name> -- ls /home/agent/.claude/skills` from the host, to confirm
   real directories rather than symlinks.

## Open decisions

- **Which of mattpocock's sets to vendor.** Currently `engineering/*` and
  `productivity/*`, which is 24 skills. The old `experimental/` tree also
  carried `in-progress/*` (explicitly unfinished) and `misc/*` (repo-specific:
  `scaffold-exercises`, `migrate-to-shoehorn`). Adding them back is one line in
  `skills.json`.
- **`agent-init` was restored from a sandbox copy.** It was untracked, and it
  had already disappeared from the kit directory before the move (the `mv`
  failed with "cannot stat"). The copy at `/home/agent/skills/agent-init`, which
  the kit shipped when this sandbox started, is byte-identical to what the file
  held earlier in the session, and that is what is now in
  `env/.agents/skills/agent-init`. Worth a glance before committing.

## Commit split

1. move skills to `env/.agents/`, 2. add `pull-skills` and vendor the mattpocock
set, 3. add `sync-skills` and wire up `sbx-up`, 4. manifests, 5. drop the symlink
hook, 6. docs. Each one leaves the repo working, and the race stays fixed from
commit 5 onward.
