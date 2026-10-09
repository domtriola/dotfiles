---
name: skills-init
description: Set up a repo for the skills. Makes AGENTS.md the source of agent instructions, and records the tracker for author-spec, author-tickets, wayfinder, and triage.
disable-model-invocation: true
---

Set up the current repo so that every agent reads one instruction file, `AGENTS.md`, and so that the skills that read `docs/agents/issue-tracker.md` know where its specs, tickets, and maps live.

1. **Make `AGENTS.md` the source of truth.** `CLAUDE.md` must hold only the line `@AGENTS.md`.
   - Neither file exists: create `AGENTS.md` with only a `# <repo name>` heading, and create `CLAUDE.md`.
   - `CLAUDE.md` has content other than `@AGENTS.md`: move that content into `AGENTS.md` (create it, or merge into the existing file without duplicating lines), then replace `CLAUDE.md` with `@AGENTS.md`. Show the user the difference and ask before you write.
   - `AGENTS.md` exists and `CLAUDE.md` does not: create `CLAUDE.md`.
2. Ask the user which tracker the repo uses, unless they already said: `local` (Markdown specs in the repo) or `github` (GitHub issues). Tell them that the `triage` skill needs `github`. For `github`, check that `gh issue list --limit 1` works, and stop with its error if it does not.
3. Write the matching template to `docs/agents/issue-tracker.md`: [issue-tracker-local.md](issue-tracker-local.md) or [issue-tracker-github.md](issue-tracker-github.md). If the file already exists, show the user the difference and ask before you replace it.

The setup is done when `AGENTS.md` holds all the agent instructions, `CLAUDE.md` holds only `@AGENTS.md`, and `docs/agents/issue-tracker.md` holds the template the user chose.
