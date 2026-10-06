---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Use when the user says "diagnose"/"debug this", or reports something broken/throwing/failing/slow.
---

A discipline for hard bugs. Skip a phase only with an explicit reason. Use the vocabulary in `GLOSSARY.md`, and check the ADRs in the area.

**Redact every secret** in the commands, outputs, and artifacts that you show: write `<REDACTED>` in its place. Build loops against env vars, so that credentials stay in the environment, and quote only the lines of an artifact that carry the signal. If the redacted output is not enough, say so and ask the user.

## Phase 1: Build a feedback loop

**This is the skill.** With a **tight** pass/fail signal that goes red on _this_ bug, you will find the cause; bisection, hypotheses, and instrumentation only consume it. Without one, no amount of reading code will help. Spend most of your effort here. Be creative and **relentless**.

Ways to build one, in about this order:

1. **Failing test** at whatever seam reaches the bug: unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) that drives the UI and asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **HITL bash script.** Last resort. If a human must click, drive _them_ with [`scripts/hitl-loop.template.sh`](scripts/hitl-loop.template.sh) so the loop is still structured. Captured output feeds back to you.

Then **tighten** the loop: make it faster (cache setup, narrow the scope), sharper (assert the specific symptom, not "did not crash"), and more deterministic (pin time, seed the RNG, isolate the filesystem, freeze the network). For a non-deterministic bug, the goal is a higher reproduction rate, not a clean repro: loop the trigger 100 times, parallelize, add stress, narrow timing windows, inject sleeps. A 50% flake is debuggable; a 1% flake is not, so keep raising the rate. A 30-second flaky loop is barely better than no loop; a 2-second deterministic one is tight.

If you cannot build a loop, stop and say so, with what you tried. Ask the user for access to an environment that reproduces it, a redacted artifact (HAR file, log dump, core dump, timestamped screen recording), or permission to add temporary production instrumentation. Form no hypothesis without a loop.

Phase 1 is done when you can name **one command** (a script, a test invocation, a curl) that you **already ran** (show it and its redacted output), and that is:

- [ ] **Red-capable**: it drives the actual bug code path and asserts the **user's exact symptom**, so it can go red on this bug and green once fixed. Not "runs without erroring"; it must be able to _catch this specific bug_.
- [ ] **Deterministic**: same verdict every run (flaky bugs: a pinned, high reproduction rate, per above).
- [ ] **Fast**: seconds, not minutes.
- [ ] **Agent-runnable**: you can run it unattended; a human in the loop only via [`scripts/hitl-loop.template.sh`](scripts/hitl-loop.template.sh).

If you catch yourself reading code to build a theory before this command exists, stop and go back to the loop: a hypothesis without a loop is the exact failure this skill prevents. No red-capable command, no Phase 2.

## Phase 2: Reproduce and minimize

Run the loop and watch it go red. Confirm that:

- [ ] It produces the failure that the **user** described, not a nearby one. Wrong bug, wrong fix.
- [ ] It reproduces across runs (or at a debuggable rate).
- [ ] You captured the exact symptom (error message, wrong output, timing), so that later phases can check the fix against it.

Then **minimize**: cut inputs, callers, config, data, and steps one at a time, and run the loop after each cut. A minimal repro leaves fewer suspects for Phase 3 and becomes the regression test in Phase 5. This phase is done when every remaining element is load-bearing: removing any one of them makes the loop go green. Start Phase 3 only after you reproduce **and** minimize.

## Phase 3: Hypothesize

Write **3 to 5 ranked hypotheses** before you test any of them, so that you do not anchor on the first idea. Each one is **falsifiable**: "If <X> is the cause, then <changing Y> makes the bug disappear, and <changing Z> makes it worse." A hypothesis without a prediction is a vibe: sharpen it or drop it.

Show the ranked list to the user before you test. Their domain knowledge can re-rank it at once ("we just deployed a change to #3"). If the user is away, continue with your ranking.

## Phase 4: Instrument

Each probe tests one prediction from Phase 3. Change one variable at a time. Prefer a debugger or REPL (one breakpoint beats ten logs), then targeted logs at the boundaries that separate the hypotheses. Tag every debug log with a unique prefix, for example `[DEBUG-a4f2]`, so that cleanup is one grep.

For a performance regression, measure instead of logging: get a baseline (timing harness, profiler, query plan), then bisect.

## Phase 5: Fix and regression test

Write the regression test before the fix, at a **correct seam**: one where the test exercises the real bug pattern as it occurs at the call site. A seam that is too shallow (one caller when the bug needs several, a unit test that cannot replay the chain) gives false confidence. If no correct seam exists, that is the finding: the architecture prevents locking the bug down. Record it.

With a correct seam: turn the minimal repro into a failing test, watch it fail, fix, watch it pass, then run the Phase 1 loop against the original scenario.

## Phase 6: Cleanup

The work is done when:

- [ ] The Phase 1 loop no longer reproduces the original bug.
- [ ] The regression test passes, or the missing seam is recorded.
- [ ] No `[DEBUG-...]` instrumentation remains (grep the prefix).
- [ ] Throwaway harnesses are deleted, or moved to a clearly marked debug location.
- [ ] The commit or PR message states the hypothesis that was correct.
