# Issue tracker: GitHub

Specs, tickets, and maps for this repo are GitHub issues. Use the `gh` CLI, which infers the repo from `git remote`. In `gh api` paths, `gh` fills in `{owner}` and `{repo}`.

## Specs

- **Publish**: `gh issue create --title "..." --body-file <file>`.
- **Fetch**: `gh issue view <number> --comments`.
- **Comment**: `gh issue comment <number> --body "..."`.
- **Close**: put `Closes #<number>` in the body of the PR that implements the spec, so the issue closes when the PR merges. Before that, move anything that must outlive the spec into `GLOSSARY.md` or an ADR.

## Tickets

- **Publish**: `gh issue create --label ready-for-agent --title "..." --body-file <file>`, then make it a sub-issue of its spec with `gh issue edit <spec> --add-sub-issue <ticket>` (`gh` 2.94 or later). If sub-issues are not available, put `Part of #<spec>` at the top of the body.
- **Blocking**: GitHub's native issue dependencies, which show in the GitHub UI. Add an edge with `gh api --method POST repos/{owner}/{repo}/issues/<ticket>/dependencies/blocked_by -F issue_id=<blocker-id>`. `<blocker-id>` is the database id from `gh api repos/{owner}/{repo}/issues/<number> --jq .id`, not the issue number. If dependencies are not available, put `Blocked by: #<n>, #<n>` at the top of the body.
- **Frontier**: the open sub-issues of the parent (`gh api repos/{owner}/{repo}/issues/<parent>/sub_issues`) that have no assignee and no open blocker (`issue_dependencies_summary.blocked_by` is 0). The first in order wins.
- **Claim**: `gh issue edit <number> --add-assignee @me`, before any other work.
- **Close**: put `Closes #<number>` in the PR body, as for a spec.

## Maps

The `wayfinder` skill uses these operations.

- **Map**: one issue with the label `wayfinder:map`.
- **Map ticket**: a sub-issue of the map with the label `wayfinder:<type>`. Publish, block, find the frontier, and claim as for tickets.
- **Resolve**: `gh issue comment <number> --body "<answer>"`, then `gh issue close <number>`, then add a line to the map's "Decisions so far" with `gh issue edit <map> --body-file <file>`.

## Triage

- **Labels**: the role names in the `triage` skill are the label names. Create a missing label with `gh label create <name>`.
- **List**: `gh issue list --state open --json number,title,labels,createdAt,updatedAt` with `--label` filters, or `--search "no:label"` for unlabeled issues.
- **Label**: `gh issue edit <number> --add-label "..." --remove-label "..."`.
- **Close**: `gh issue close <number> --comment "..."`.

**PRs as a request surface: no.** Set this to `yes` if this repo triages external PRs as requests. Then:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>`.
- **List external PRs**: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, labels: [.labels[].name]}'`.
- **Comment, label, close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

Issues and PRs share one number space, so `#42` can be either. Try `gh pr view 42` first, then `gh issue view 42`.
