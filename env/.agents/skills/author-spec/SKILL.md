---
name: author-spec
description: Turn the current conversation into a spec and publish it to the project's tracker. Synthesis only, no interview.
disable-model-invocation: true
---

Turn what the conversation and the codebase already establish into a spec. Synthesize: the only question for the user is the seam check in step 2.

Read `docs/agents/issue-tracker.md` first. If it is missing, stop and tell the user to run the `skills-init` skill.

## Process

1. Explore the repo until you understand the current state of the area the spec touches. Use the vocabulary in `GLOSSARY.md` throughout the spec, and respect any ADRs in that area.

2. Sketch the seams at which the feature will be tested. Use "seam", "module", and "interface" as the `codebase-design` skill defines them. Prefer existing seams to new ones, and the highest seam possible. The fewer seams across the codebase, the better: the ideal number is one. Confirm the seams with the user.

3. Write the spec with the template below, then publish it the way `docs/agents/issue-tracker.md` describes.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A long, numbered list of user stories that covers every aspect of the feature. Each one has this format:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

## Implementation Decisions

The implementation decisions that were made. For example:

- The modules that will be built or modified, and the interfaces that change
- Technical clarifications from the developer
- Architectural decisions
- Schema changes and API contracts
- Specific interactions

Describe modules and interfaces by name, and leave file paths and code snippets to the code, where they cannot go stale.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline the decision-rich part within the relevant decision and note that it came from a prototype.

## Testing Decisions

- What makes a good test here (external behavior, not implementation details)
- The seams agreed in step 2, and which modules are tested at each
- Prior art: similar tests in the codebase

## Out of Scope

The things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
