---
name: implement
description: Implement a spec or a ready-for-agent issue, test-first, through to an open PR. Use when the user says to implement a spec, an issue, or a ticket.
---

Implement the spec or issue the user names, or the one that this session triaged.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. Fetch the spec or issue the way that file describes. An issue with an agent brief is a spec: its acceptance criteria are the user stories, and its out-of-scope list bounds the work.

The instruction to implement is the approval for every step below, including the commit, the push, and the PR. Do not stop to ask for them. Stop and ask only when the spec contradicts the code, or when a step is a one-way door (deleting data, a force push, a change outside the repo). Never merge the PR.

1. Claim the issue the way `docs/agents/issue-tracker.md` describes. Create a branch for the work, unless you are already on one that is not the default branch.
2. Build each user story test-first with the `tdd` skill, at the seams the spec agreed. Run the type checker with the tests of each slice.
3. Review the branch against the default branch with the `code-review` skill, and fix what it finds.
4. Close the spec the way `docs/agents/issue-tracker.md` describes, commit, push the branch, and open a PR with a body from the `author-pr` skill.

When the spec leaves a choice open, make the choice that fits the spec and the repo's docs, and list it in the PR body for the reviewer.

## Keep the context small

Every turn reads the whole context again, so text that enters it early costs on every later turn.

- **Explore through a sub-agent.** When you must read more than three or four files to learn the code, give the reading to a sub-agent (an `Explore` agent, if there is one) and ask it for paths, signatures, and facts, not file contents. If you cannot dispatch a sub-agent, read only the parts of each file that you need. Read a whole file only when you will edit it.
- **Edit with small, exact replacements** in the edit tool. A whole-file rewrite through a script or a heredoc enters the context once in the call, and again when the harness reports the change.
- **Format once, at the end.** Run the formatter on the changed files only, just before the commit. A formatter run over the whole repo changes files that you read, and the harness reports each of them again.

The work is done when the PR is open, and every user story in the spec is implemented or listed in the PR body as not done with the reason. Then tell the user to start a new session for the follow-up work (review fixes, a retro), with the PR number as its input.
