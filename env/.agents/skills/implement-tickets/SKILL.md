---
name: implement-tickets
description: Implement a spec that author-tickets split into tickets, with parallel sub-agents on one integration branch.
disable-model-invocation: true
---

Implement the spec the user names, through its tickets.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. If the spec has no tickets, tell the user to run the `author-tickets` skill first.

The tickets are a **task graph**, not a list. The **frontier** is every ticket that is not merged yet and whose blockers are all merged into the integration branch. Work it out from the task graph, not from the tracker: the tickets close only at the end, so until then the tracker shows merged blockers as open.

Talk to sub-agents through **context pointers** (the spec, the tickets, the exploration notes, earlier commits), and keep the messages short. A sub-agent reads the pointer; it does not need a copy.

## Steps

1. Read the spec and its tickets, and build the task graph.
2. Optional: dispatch an **explorer** sub-agent for the codebase files and external docs that the tickets need. It saves Markdown notes in a directory outside the repo, so that every later sub-agent can read them.
3. Create the integration branch from the default branch.
4. For each unclaimed frontier ticket, claim it the way `docs/agents/issue-tracker.md` describes, and dispatch an **implementer** sub-agent in the background, in its own worktree (`git worktree add`) on its own branch from the integration branch. Each implementer:
   - confirms that its branch starts from the integration branch, and resets onto it if not;
   - builds the ticket test-first with the `tdd` skill;
   - merges the integration branch tip into its own branch before it reports done.
5. When an implementer finishes, dispatch a **merger** sub-agent to merge its branch into the integration branch. If this opens new frontier tickets, go back to step 4 for them.
6. When every ticket is merged, review the integration branch against the default branch with the `code-review` skill. Dispatch one implementer to fix every finding.
7. Push the integration branch and open a PR with a body from the `author-pr` skill. Close the spec and every ticket the way `docs/agents/issue-tracker.md` describes.
8. Remove every implementer worktree.

If you cannot dispatch sub-agents, do the same work yourself: take the frontier tickets one at a time, in order, on the integration branch.

The work is done when every ticket is merged and closed, the PR is open, and no worktree remains.
