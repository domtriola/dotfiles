---
name: skills-init
description: Set up a repo for the spec, implement, and review skills.
disable-model-invocation: true
---

Set up the current repo so that `author-spec`, `implement`, and `code-review` know where its specs live.

1. Ask the user which tracker the repo uses, unless they already said: `local` (Markdown specs in the repo) or `github` (GitHub issues). For `github`, check that `gh issue list --limit 1` works, and stop with its error if it does not.
2. Write the matching template to `docs/agents/issue-tracker.md`: [issue-tracker-local.md](issue-tracker-local.md) or [issue-tracker-github.md](issue-tracker-github.md). If the file already exists, show the user the difference and ask before you replace it.

The setup is done when `docs/agents/issue-tracker.md` exists and holds the template the user chose.
