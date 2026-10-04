---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities, present them as a Markdown report, then grill through the one you pick.
disable-model-invocation: true
---

Find architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

Read the `codebase-design` skill first. Use its vocabulary exactly in every suggestion (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and apply its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Name the domain with the terms in `GLOSSARY.md`. ADRs in `docs/adr/` record decisions that this review does not reopen without cause.

## 1. Explore

**Scope before you scan: YAGNI.** Deepening a module pays off when the module changes again, so weight the parts of the codebase that changed recently.

- If the user named a direction (a module, a subsystem, a pain point), use it.
- Otherwise, walk back a good stretch of `git log --oneline` to find the hot spots, and look there first. If the changes are scattered, widen the net.

Read `GLOSSARY.md` and the ADRs for the area first.

Then dispatch a sub-agent to walk the codebase; if you cannot dispatch one, walk it yourself. Explore organically and note where you feel friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where were pure functions extracted only for testability, while the real bugs hide in how they are called (no **locality**)?
- Where do tightly coupled modules leak across their seams?
- Which parts are untested, or hard to test through their current interface?

Apply the **deletion test** to each suspected shallow module: would deleting it concentrate complexity, or only move it? "Concentrates" is the signal.

## 2. Report the candidates

Write the report to `<tmpdir>/architecture-review-<timestamp>.md`, where `<tmpdir>` is `$TMPDIR` or `/tmp`, so nothing lands in the repo. Use the format in [REPORT.md](REPORT.md). Tell the user the absolute path.

If a candidate contradicts an ADR, include it only when the friction is real enough to reopen the ADR, and mark the conflict in its card.

Propose no interfaces yet. When the file is written, ask the user: "Which of these would you like to explore?"

## 3. Grill the chosen candidate

When the user picks a candidate, walk the decision tree with them through the `grilling` skill: constraints, dependencies, the shape of the deepened module, what sits behind the seam, and which tests survive.

Keep the domain model current as decisions crystallize, with the `domain-modeling` skill:

- Add each new concept that names a deepened module to `GLOSSARY.md`, and update a fuzzy term as soon as it sharpens.
- When the user rejects the candidate for a load-bearing reason, offer an ADR so that later reviews do not suggest it again.

To explore alternative interfaces for the deepened module, use the design-it-twice pattern in the `codebase-design` skill.
