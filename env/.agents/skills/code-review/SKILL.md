---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) on three axes, Standards, Spec, and Security. Use when reviewing a branch, a PR, or work in progress, or on "review since X".
---

Three-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Security**: does the code hold the repo's threat model and security posture?

Each axis is reviewed in its own context, so that no axis pollutes another, then this skill aggregates their findings.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside the reviews.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. A spec or issue the user passed as an argument.
2. A spec referenced by the commit messages or the branch name, fetched the way `docs/agents/issue-tracker.md` describes.
3. If nothing is found, ask the user where the spec is. If there is none, the **Spec** review is skipped and reports "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`. On top of these, the Standards axis always carries the smell baseline in [SMELLS.md](SMELLS.md), which applies even when a repo documents nothing.

### 4. Identify the threat model

Read `docs/threat-model/product.md`, and every feature model in `docs/threat-model/` whose **Scope** covers a module, entry point, or data flow that the diff touches. Also read the repo's security docs, such as `SECURITY.md`.

If `docs/threat-model/` is missing, the **Security** review still runs against the baseline alone, and the final report tells the user to run the `author-threat-model` skill.

### 5. Run the three reviews

If you can dispatch sub-agents, run the three reviews as parallel sub-agents, each given the input below. If you cannot, run them in order (Standards, Security, Spec), and write each report before you start the next. Leave a finished report unchanged after you read the next axis's sources.

**Standards review** input:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus [SMELLS.md](SMELLS.md)** pasted in full (a sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec review** input:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec review and note this in the final report.

**Security review** input:

- The diff command and commit list.
- The paths of the threat models and security docs you found in step 4, or "no threat model".
- [SECURITY.md](SECURITY.md) pasted in full (a sub-agent has no other access to it). It holds the brief.

### 6. Aggregate

Present the three reports under `## Standards`, `## Spec`, and `## Security` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the axes are deliberately separate (see _Why separate axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent. If the Security review reported threat-model drift, or found no threat model, add one line that tells the user to run the `author-threat-model` skill.

## Why separate axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Clean code that does exactly what the issue asked, and also opens a path across a trust boundary → **Standards and Spec pass, Security fail.**

Reporting them separately stops one axis from masking another. The Security reviewer does not read the spec, so that a spec which asks for something unsafe does not make it look safe.
