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
- **Claimed**: a ticket that has the `in-progress` label, an assignee, or an open PR that closes it. List the issues that open PRs close with `gh pr list --state open --limit 1000 --json closingIssuesReferences --jq '[.[].closingIssuesReferences[].number]'`.
- **Frontier**: the open sub-issues of the parent (`gh api repos/{owner}/{repo}/issues/<parent>/sub_issues`) that have no open blocker (`issue_dependencies_summary.blocked_by` is 0). Take the first unclaimed one, in order.
- **Ready**: the open `ready-for-agent` issues in the repo that have no open blocker, are not claimed, and are not in a later milestone (see **Milestones**). These commands drop the issues in a later milestone, and the blocked, assigned, and `in-progress` issues. Then drop the issues that open PRs close.

  ```sh
  later="$(gh api 'repos/{owner}/{repo}/milestones?state=open&per_page=100' \
    --jq 'sort_by([.due_on == null, .due_on, .number])
          | (map(.open_issues > 0) | index(true)) as $i
          | if $i == null then [] else .[$i + 1:] | map(.number) end')"
  gh api --paginate 'repos/{owner}/{repo}/issues?state=open&labels=ready-for-agent&per_page=100' |
    jq -r --argjson later "$later" \
      '.[] | select(.pull_request | not) | select(.assignees == [])
       | select(any(.labels[]; .name == "in-progress") | not)
       | select(.issue_dependencies_summary.blocked_by == 0)
       | select(.milestone.number | IN($later[]) | not) | "#\(.number)\t\(.title)"'
  ```
- **Claim**: `gh issue edit <number> --add-label in-progress`, before any other work. Create the label with `gh label create in-progress` if it is missing. Do not assign the issue to yourself: a GitHub App token cannot assign `@me`, and an assignee means who owns the issue, not that work started.
- **Release**: `gh issue edit <number> --remove-label in-progress`, if you stop before the work is done.
- **Close**: put `Closes #<number>` in the PR body, as for a spec.

## Milestones

- A **milestone is a phase**, such as Beta or GA. A feature that spans many tickets is a spec with sub-issues, not a milestone.
- **Order**: by due date; milestones with no due date come last, then by creation (milestone number).
- **Current milestone**: the earliest open milestone that has open issues. It moves on by itself when its last issue closes.
- **Later**: an issue in an open milestone after the current one. An issue with no milestone, or in a closed milestone, is current work.
- Work that started (claimed, or with an open PR) is never held back.

List the open milestones with `gh api 'repos/{owner}/{repo}/milestones?state=open&sort=due_on&direction=asc'`. Each milestone has `open_issues`: skip those with 0. Sort them by the **Order** rule yourself, with `--jq 'sort_by([.due_on == null, .due_on, .number])'`. The issues API gives the milestone of each issue as `.milestone.number`, `.milestone.state`, and `.milestone.due_on` (`.milestone` is null for an issue with no milestone). Set the milestone of an issue with `gh issue edit <number> --milestone '<title>'`, in single quotes, because the title comes from GitHub.

## Maps

The `wayfinder` skill uses these operations.

- **Map**: one issue with the label `wayfinder:map`.
- **Map ticket**: a sub-issue of the map with the label `wayfinder:<type>`. Publish, block, find the frontier, claim, and release as for tickets.
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
