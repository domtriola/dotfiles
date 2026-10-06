---
name: skills-init
description: Set up a repo for the skills that use its tracker, such as author-spec, author-tickets, wayfinder, and triage.
disable-model-invocation: true
---

Set up the current repo so that the skills that read `docs/agents/issue-tracker.md` know where its specs, tickets, and maps live.

1. Ask the user which tracker the repo uses, unless they already said: `local` (Markdown specs in the repo) or `github` (GitHub issues). Tell them that the `triage` skill needs `github`. For `github`, check that `gh issue list --limit 1` works, and stop with its error if it does not.
2. Write the matching template to `docs/agents/issue-tracker.md`: [issue-tracker-local.md](issue-tracker-local.md) or [issue-tracker-github.md](issue-tracker-github.md). If the file already exists, show the user the difference and ask before you replace it.

The setup is done when `docs/agents/issue-tracker.md` exists and holds the template the user chose.
