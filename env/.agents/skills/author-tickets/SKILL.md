---
name: author-tickets
description: Split a spec, plan, or the current conversation into tracer-bullet tickets with blocking edges, and publish them to the project's tracker.
disable-model-invocation: true
---

Split the work into **tickets**: tracer-bullet vertical slices. Each ticket names the tickets that **block** it.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill.

## Process

1. Work from the conversation. If the user names a spec or an issue, fetch it with its comments, the way `docs/agents/issue-tracker.md` describes.
2. Explore the area the work touches, unless you already did. Use the vocabulary in `GLOSSARY.md`, and respect the ADRs in that area. Look for a prefactor that makes the change easy: "make the change easy, then make the easy change."
3. Draft the slices with the rules below. Give each ticket its blocking edges: the tickets that must close before it can start.
4. Show the breakdown to the user as a numbered list, with the title, the blockers, and the behavior that each ticket delivers. Ask whether the granularity is correct, whether each edge really gates its ticket, and which tickets to merge or split. Iterate until the user approves.
5. Publish the tickets with the template below, the way `docs/agents/issue-tracker.md` describes. Publish blockers first, so that each edge can refer to a real identifier. Leave the parent spec or issue open and unchanged.

The work is done when every approved ticket is published with its edges.

## Slices

- A slice cuts a narrow but complete path through every layer (schema, API, UI, tests).
- A finished slice is demoable or verifiable on its own.
- A slice fits in one fresh context window.
- Prefactors come first.

**Wide refactors** are the exception. A wide refactor is one mechanical change (rename a column, retype a shared symbol) with a blast radius across the whole codebase, so no vertical slice can land green. Sequence it as **expand–contract**:

1. **Expand**: add the new form beside the old, so nothing breaks.
2. **Migrate**: move the call sites in batches sized by blast radius (per package, per directory). Each batch is a ticket blocked by the expand, and CI stays green because the old form still exists.
3. **Contract**: delete the old form in a ticket blocked by every batch.

If a batch cannot stay green alone, the batches share an integration branch, and they all block a final integrate-and-verify ticket. Only that ticket promises green.

## Ticket template

```markdown
## Parent

<the spec or issue this ticket came from; omit when there is none>

## What to build

<the end-to-end behavior this ticket makes work, from the user's perspective, not a list of layers>

## Acceptance criteria

- [ ] <criterion>

## Blocked by

<each blocking ticket, or "None (can start immediately)"; omit when the tracker holds the edges>
```

Describe modules and interfaces by name, and leave file paths and code snippets to the code, where they cannot go stale. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline the decision-rich part and note that it came from a prototype.
