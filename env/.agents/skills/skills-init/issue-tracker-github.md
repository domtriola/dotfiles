# Issue tracker: GitHub

Specs for this repo are GitHub issues. Use the `gh` CLI, which infers the repo from `git remote`.

- **Publish**: `gh issue create --title "..." --body-file <file>`.
- **Fetch**: `gh issue view <number> --comments`.
- **Comment**: `gh issue comment <number> --body "..."`.
- **Close**: put `Closes #<number>` in the body of the PR that implements the spec, so the issue closes when the PR merges. Before that, move anything that must outlive the spec into `GLOSSARY.md` or an ADR.
