---
name: design-review
description: Review a change or a UI for usability, component choice, and design-system rules. Use when reviewing anything the user sees, or for the Design axis of a code review.
---

# Design review

Review what the user sees against the project's design principles, and name the principle that each finding breaks.

## Process

1. **Load the principles.** Use the `design` skill: it reads `docs/design.md` and gives the Laws of UX, the component rules, and the design-system rules. If `docs/design.md` is missing, note it for the report.
2. **Pin the scope.** Review the diff or the files the user names. List the screens, states, and components that the change affects.
3. **Look at the UI.** If the project has the `playwright-cli` skill, start the app the way the project documents it (README or package scripts), and use that skill to open each affected screen. Look at every state the change touches: empty, loading, error, and full. If the project has no `playwright-cli` skill, or the app does not start, review the code only and say so in the report.
4. **Review.** Check the scope against each heuristic below, each priority in `docs/design.md`, the component rules, and the design-system rules.
5. **Report.** Write each finding as: the principle it breaks, where (a `file:line` or a screen and state), what the user experiences, and the fix. Separate hard violations (a design-system rule, a component used against its rule) from judgement calls. Put findings that break a priority from `docs/design.md` first.

The review is done when every heuristic, every priority, and every rule has been checked against the scope, and each finding names one of them.

## Nielsen's ten usability heuristics

Use these names exactly in findings (Jakob Nielsen, Nielsen Norman Group).

1. **Visibility of system status.** Always tell users what is happening, with fast feedback. No action with consequences happens without the user knowing.
2. **Match between the system and the real world.** Use the users' words and concepts, not internal jargon. Follow real-world conventions and natural mapping, so that controls match their effects.
3. **User control and freedom.** Users make mistakes. Give a clearly marked exit (cancel, back), and support undo and redo.
4. **Consistency and standards.** The same word or action always means the same thing. Keep consistency inside the product, and follow platform conventions.
5. **Error prevention.** Prevent slips with constraints and good defaults. Prevent mistakes by reducing what users must remember, by supporting undo, and by asking for confirmation before costly actions. Prevent high-cost errors first.
6. **Recognition rather than recall.** Keep elements, actions, and options visible, so users recognize them and do not have to remember them. Give help in context.
7. **Flexibility and efficiency of use.** Give experts accelerators (shortcuts, gestures) that novices do not have to see. Let users tailor frequent actions.
8. **Aesthetic and minimalist design.** Remove information that is irrelevant or rarely needed. Every extra item competes with the relevant items.
9. **Help users recognize, diagnose, and recover from errors.** Write error messages in plain language. Say what the problem is, and give a solution.
10. **Help and documentation.** The design should need no explanation. When it needs some, make the help easy to search, focused on the task, and short, with concrete steps.
