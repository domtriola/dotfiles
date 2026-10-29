---
name: backlog
description: Check in on the open issues, and get an order for the work that waits on you.
disable-model-invocation: true
---

Give the maintainer a bird's-eye view of the open issues, and an order to work through what waits on them.

1. **Ask** the maintainer what their biggest priority is now, for example "ship the alpha" or "keep the agents busy". Wait for the answer.
2. **Gather.** Read `docs/agents/issue-tracker.md`. If it is missing, stop and tell the user to run the `skills-init` skill. Fetch every open issue with its labels, assignees, and blockers, and every open PR with the issues it closes.
3. **Find the current milestone** with the **Milestones** rules in `docs/agents/issue-tracker.md`:
   - A **milestone is a phase**, such as Beta or GA. A feature that spans many tickets is a spec with sub-issues, not a milestone.
   - **Order**: by due date; milestones with no due date come last, then by creation (milestone number).
   - **Current milestone**: the earliest open milestone that has open issues. It moves on by itself when its last issue closes.
   - **Later**: an issue in an open milestone after the current one. An issue with no milestone, or in a closed milestone, is current work.
   - Work that started (claimed, or with an open PR) is never held back.

   Tell the maintainer which milestone you use, so that they can correct it. If the repo has no milestones, use all issues.

4. **Sort** each issue of current work, and each claimed issue in a later milestone, into the first bucket that fits, in this order. Use the tracker's rules for **Claimed**, **Blocking**, and **Ready**.
   - **Waiting on review**: claimed, with an open PR. Name the PR.
   - **In progress**: claimed, with no PR.
   - **Blocked**: has an open blocker, or `needs-info`. Name the blocker (or the reporter), and the PR or decision that frees it.
   - **Ready**: matches the Ready rule.
   - **Waiting on the maintainer**: every other issue, for example `needs-triage`, `ready-for-human`, an open question, or no state label.
5. **Report.** Show a table of the buckets with a count each. Under the table, list each bucket with one line per issue: number, title, and what it waits on. Then:
   - Give the later milestones only as one count per milestone.
6. **Suggest an order** of at most five actions for the maintainer. Rank them first by the stated priority, then by how many issues each action unblocks. Merging a PR unblocks the issues that wait on it. Answering a question unblocks the issues that the question blocks.

The work is done when every open issue is in exactly one bucket or in a later-milestone count, and the maintainer has an ordered list of actions.
