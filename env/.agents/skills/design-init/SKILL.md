---
name: design-init
description: Set up a repo's design principles in docs/design.md, and install playwright-cli so that design reviews can look at the UI.
disable-model-invocation: true
---

Set up the current repo for the `design` and `design-review` skills. The only decision you ask the user for is the priorities. Do every other step without asking.

1. **Priorities.** Ask the user to describe the app in a few sentences: who uses it, and for what. From the Laws of UX in the `design` skill, propose the 3 to 5 laws that matter most for this app, in order, with one line each on what the law means for this app. If the user rejects the proposal, show every law with its one-line summary and let the user choose.
2. **Design system.** Find the style guide (a page, a Storybook, or a doc) and the file that defines the tokens or base colors (for example, `globals.css` or a Tailwind config). If you find neither, write "None yet" for each.
3. **Write `docs/design.md`** from [design-template.md](design-template.md). If the file already exists, show the user the difference and ask before you replace it.
4. **Add the pointer.** Add this line to `AGENTS.md`. If only `CLAUDE.md` exists, add it there. If neither exists, create `AGENTS.md` with only this line.

   > Read `docs/design.md` before you design, build, or review anything the user sees.

5. **Install playwright-cli in the project.** Only if the repo has a `package.json`:
   1. Add `@playwright/cli` as a dev dependency with the package manager that the lockfile shows (for example, `npm install --save-dev @playwright/cli`).
   2. Run `npx playwright-cli install --skills=agents` if the repo keeps skills in `.agents/skills/`. Otherwise run `npx playwright-cli install --skills=claude`.
   3. The same command downloads a browser. If the download fails (for example, a firewall blocks it) but the skill is installed, tell the user the error and continue.

   If the repo has no `package.json`, skip this step, and tell the user that `design-review` will review only the code.

The setup is done when `docs/design.md` holds the priorities that the user approved, the pointer line is in `AGENTS.md` or `CLAUDE.md`, and the `playwright-cli` skill is in the project or the user knows why it is not.
