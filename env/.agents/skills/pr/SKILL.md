---
name: pr
description: Write a pull request body. Use when opening a PR or writing its description.
---

Write the PR body from this template. Use the domain language from `GLOSSARY.md` if the repo has one. Start each section on its content, with at most a sentence or two of prose.

```markdown
## Summary

<one or more views>

## Evidence

- **Before:** <screenshot, output, or failing test run>
  **After:** <screenshot, output, or passing test run>

## Merge Danger

**Door:** <one-way or two-way>

<optional: why>

**Blast Radius:** <one word>

<optional: what the merge could affect>
```

## Summary

Pick the smallest view that makes the key point clear. One view is usually enough; add another only when it answers a different question. Put each view beside the short text it supports, and keep only the calls, files, props, states, and boundaries the reviewer needs.

| Point to show | View |
| --- | --- |
| Logic or an algorithm | pseudocode |
| Runtime control flow | call tree |
| UI structure | component tree, with the state and module boundaries that matter |
| File responsibility or a broad refactor | shallow file tree, one comment per entry |
| Interaction or data flow between parts | Mermaid diagram |
| What changes, when the surrounding shape already exists | `diff` of one of the views above |
| Mostly new code, or a target shape to copy | the whole code block |

A `diff` view keeps the shape of the view it changes. For a call tree:

```diff
 submitForm
   createSession
     persistPrompt
+    expandSkillMention
     launchAgent
   navigateToSession
+    subscribeToEvents
```

## Evidence

Show concrete proof, before and after, that the change works. Screenshots are best when the change is visual and the environment can capture them. Execution evidence (test results, console output) is next. For tests, show the exact test that failed before and passes after, in pseudocode.

## Merge Danger

**Door:** a two-way door is cheap to roll back. A one-way door is not: destructive actions, data migrations, and other hard-to-reverse decisions.

**Blast Radius:** the scope of what the merge could affect. Check every route, for example layout shift, breakage for consumers, and mobile responsiveness.
