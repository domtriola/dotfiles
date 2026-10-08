---
name: ux-design
description: UX principles for user interfaces. Use when designing a screen or flow, choosing a UI component, reviewing a UI for usability, or styling with design tokens.
---

# UX Design

Every design decision serves three guideposts. When two options are otherwise equal, pick the one that scores better on them.

## Guideposts

**Minimal choice.** Each choice the user sees adds decision time (Hick's Law), and too many choices hurt both the decision and how the user feels about the whole experience (choice overload).

- Show only the options this moment needs. Move the rest one step away.
- Highlight a recommended option, and give every setting a good default.
- Give long lists a way to narrow them first (search or filter).
- When the user must compare options, put them side by side.
- Simplify only until the meaning stays clear. An abstract control costs more than a second option.

**Minimal cognitive load.** Working memory holds only a few items. The task brings its own load (intrinsic); everything else the UI adds is extraneous load. Remove the extraneous load.

- Remove every element that does not help the user's current goal.
- Chunk related content into groups, and use proximity, common regions, and similarity to show the groups.
- Show labels, options, and state so the user recognizes them. Never make the user carry information from one screen to the next.
- Use the patterns users know from other products (Jakob's Law), and the words users use.
- Split a complex task into small steps, and disclose advanced features progressively.

**Maximal flow.** Flow is focused, unbroken work, with a sense of control. Friction, waiting, and doubt break it.

- Respond to every action in less than 400 ms (Doherty Threshold). If the work takes longer, show progress immediately, or update the UI optimistically.
- Give feedback for every action, so the user knows what happened and what is done.
- Keep the user in context. Prefer inline editing and undo to modal dialogs and confirmations.
- Make frequent actions fast: large, near targets (Fitts's Law), keyboard shortcuts, and remembered preferences.
- Match the challenge to the user's skill. Too hard frustrates; too easy bores.

[LAWS.md](LAWS.md) has the other Laws of UX. Read it when a decision is not covered by the guideposts.

## Choosing a component

Read [COMPONENTS.md](COMPONENTS.md) before you choose between similar components (for example, a switch or a checkbox, tabs or an accordion, radios or a select).

## Reviewing a design

Read [HEURISTICS.md](HEURISTICS.md), and review the design against each of Nielsen's ten usability heuristics. Name the violated heuristic in each finding, for example "Visibility of system status: the save has no feedback". Also check the design against each guidepost and each design-system rule.

The review is done when you have checked every heuristic, every guidepost, and every rule, and each finding names one of them.

## Design system

Before you style anything, find the project's style guide and its token file (for example, a `/style-guide` page and `globals.css`). Use what they define.

- **Use semantic tokens in components.** Reference a semantic token (for example, `--color-surface-muted`) for every color. A hex value belongs only in the token file, where the semantic tokens derive from the base colors.
- **Derive new shades from the base colors.** When you need a new shade, apply opacity to an existing base color and add it as a semantic token. This keeps the brand focused. Add a new base color only when the user approves it.
- **Reuse existing components and patterns** before you make new ones. Internal consistency is part of consistency and standards.

If the project has no style guide or token file, tell the user before you add one.
