---
name: implement
description: Implement a spec or a ready-for-agent issue, test-first, through to an open PR. Use when the user says to implement a spec, an issue, or a ticket.
---

Implement the spec or issue the user names, or the one that this session triaged.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. Fetch the spec or issue the way that file describes. An issue with an agent brief is a spec: its acceptance criteria are the user stories, and its out-of-scope list bounds the work.

The instruction to implement is the approval for every step below, including the commit, the push, and the PR. Do not stop to ask for them. Stop and ask only when the spec contradicts the code, or when a step is a one-way door (deleting data, a force push, a change outside the repo). Never merge the PR.

1. Claim the issue the way `docs/agents/issue-tracker.md` describes. Create a branch for the work, unless you are already on one that is not the default branch.
2. Build each user story test-first with the `tdd` skill, at the seams the spec agreed. Run the type checker and single test files as you go, and the full test suite once at the end.
3. Review the branch against the default branch with the `code-review` skill, and fix what it finds.
4. Close the spec the way `docs/agents/issue-tracker.md` describes, commit, push the branch, and open a PR with a body from the `author-pr` skill.

When the spec leaves a choice open, make the choice that fits the spec and the repo's docs, and list it in the PR body for the reviewer.

The work is done when the PR is open, and every user story in the spec is implemented or listed in the PR body as not done with the reason.
