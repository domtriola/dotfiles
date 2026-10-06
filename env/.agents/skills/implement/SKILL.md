---
name: implement
description: Implement a spec from the project's tracker, test-first, and open a PR.
disable-model-invocation: true
---

Implement the spec the user names.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. Fetch the spec the way that file describes.

1. Create a branch for the work, unless you are already on one that is not the default branch.
2. Build each user story test-first with the `tdd` skill, at the seams the spec agreed. Run the type checker and single test files as you go, and the full test suite once at the end.
3. Review the branch against the default branch with the `code-review` skill, and fix what it finds.
4. Close the spec the way `docs/agents/issue-tracker.md` describes, commit, push the branch, and open a PR with a body from the `author-pr` skill.

The work is done when every user story in the spec is implemented, or listed in the PR body as not done with the reason.
