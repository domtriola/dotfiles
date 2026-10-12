---
name: ready-tickets
description: List the ready tickets, which are open, unblocked, and unclaimed. Use when the user asks which tickets they can pick up.
---

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill. If it has no **Ready** rule, tell the user to run the `skills-init` skill again to refresh it.

List the ready tickets the way that file describes. Show them as a table of number and title, or of path and title for the local tracker.

The work is done when the table shows every ready ticket, or you tell the user that no ticket is ready.
