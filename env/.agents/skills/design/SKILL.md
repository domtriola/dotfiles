---
name: design
description: UX principles for anything the user sees. Use when designing or building a screen, flow, component, copy, or style.
---

# Design

Read `docs/design.md` first. Its **Priorities** are the laws that win when two laws conflict, and its **Design system** section holds the project's styling rules. If the file is missing, give all laws equal weight, use the default design-system rules below, and tell the user once to run `design-init`.

Before you choose between similar components (for example, a switch or a checkbox, tabs or an accordion), read [COMPONENTS.md](COMPONENTS.md).

## Laws of UX

The laws collected by Jon Yablonski. Each gives what it means for a design.

### Choice and decisions

- **Hick's Law.** Decision time grows with the number and complexity of choices. Show only the options this moment needs, highlight a recommended option, and split complex tasks into steps.
- **Choice overload.** Too many options hurt the decision and how the user feels about the whole experience. Give long lists search or filters, and put options the user must compare side by side.
- **Tesler's Law.** Some complexity cannot be removed. Move it from the user to the system with good defaults and inferred values. Simplify only until the meaning stays clear.
- **Occam's razor.** Of two designs that work equally well, choose the one with fewer parts.
- **Pareto principle.** About 80% of use comes from about 20% of features. Make that 20% excellent and easy to reach.
- **Cognitive bias.** Users decide with shortcuts that bias them. Design defaults and framing honestly.

### Memory and attention

- **Cognitive load.** The task brings its own load. Everything else the UI adds is extraneous load, so remove every element that does not help the user's current goal.
- **Working memory.** Users hold only a little at a time. Keep labels, options, and state visible, so the user recognizes them and never carries information from one screen to the next.
- **Miller's Law.** Working memory holds about 7 (±2) items. Chunk content into groups. Do not use the number as a hard limit on menu items.
- **Chunking.** Group related items into meaningful wholes, such as the parts of a phone number or sections of a form.
- **Serial position effect.** Users remember the first and last items in a list best. Put the most important items at the start and end.
- **Selective attention.** Users notice only what relates to their goal, and they ignore what looks like an advertisement. Put important information where the user's task already looks.
- **Von Restorff effect.** The one item that differs is the one users remember. Use it only for the most important item.

### Perception and grouping

- **Law of proximity.** Items near each other read as a group. Spacing is the cheapest way to group.
- **Law of common region.** Items inside one clear boundary (a card, a panel) read as a group.
- **Law of similarity.** Items that look the same read as related. Make items that act differently look different.
- **Law of uniform connectedness.** Items joined by a line or a shared frame read as more related than items that are only near.
- **Law of Prägnanz.** People see complex shapes as the simplest possible form. Use simple, clear shapes.
- **Aesthetic-usability effect.** Users think an attractive design is easier to use, and they tolerate small problems in it. Polish also hides problems, so test with real tasks.

### Expectations

- **Jakob's Law.** Users spend most of their time in other products. Use the patterns and words they already know.
- **Mental model.** Users have a model of how the system works. Match it, or teach the new model explicitly.
- **Paradox of the active user.** Users start immediately and do not read manuals. Put guidance in context, where the user needs it.
- **Postel's Law.** Accept input liberally (formats, spacing, case), and give output strictly and consistently.

### Speed and flow

- **Flow.** Focused, unbroken work with a sense of control. Give feedback for every action, keep the user in context (inline editing and undo before modal dialogs and confirmations), and match the challenge to the user's skill.
- **Doherty Threshold.** Respond in less than 400 ms. If the work takes longer, show progress immediately, or update the UI optimistically.
- **Fitts's Law.** The time to reach a target depends on its distance and size. Make frequent and important targets large and near, with enough space between them.
- **Goal-gradient effect.** Users move faster as they get closer to a goal. Show progress, and give a head start when you can.
- **Zeigarnik effect.** Users remember unfinished tasks. Show clear progress for incomplete work, so the user can continue.
- **Peak-end rule.** Users judge an experience by its most intense moment and by its end. Make both good, for example a clear success state.
- **Parkinson's Law.** A task takes all the time it is given. Make tasks shorter than users expect, for example with autofill.

## Design system

Find the project's style guide and its token file (for example, a style-guide page and `globals.css`) before you style anything, and use what they define. When `docs/design.md` gives other rules, its rules win. The default rules:

- **Use semantic tokens in components.** Reference a semantic token (for example, `--color-surface-muted`) for every color. A hex value belongs only in the token file, where the semantic tokens derive from the base colors.
- **Derive new shades from the base colors.** When you need a new shade, apply opacity to an existing base color and add it as a semantic token. This keeps the brand focused. Add a new base color only when the user approves it.
- **Reuse existing components and patterns** before you make new ones.
