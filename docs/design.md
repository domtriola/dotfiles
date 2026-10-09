# Design

The `design` and `design-review` skills read this file. Edit it when the project's priorities or design system change.

The commands run only in a terminal. Their output is the whole user interface, so `design-review` reviews the code and the command output, not a browser.

## Who uses it, and for what

One person runs these commands in a terminal to make a machine match its profile. `sync-env` copies the dotfiles, `setup` runs the setup steps, `doctor` checks the result, and the `sbx-*` commands manage sandboxes. The machines go from a macOS workstation to a headless Ubuntu server and a minimal Qubes VM. The user usually runs a command after a change, reads the output to find what went wrong or what needs a decision, and then goes back to work.

## Priorities

When two laws of UX conflict, the higher law wins.

1. **Selective attention.** Failures, drift and prompts show up where the eye already looks. Routine success stays quiet.
2. **Peak-end rule.** Every command ends with a short summary (counts and a verdict), because the end of the output is what the user reads.
3. **Law of similarity.** A status has the same word, color and column in every command, so `ok` in `sync-env` looks like `ok` in `doctor`.
4. **Cognitive load.** Remove every line that does not help the user read the result. For example, the raw file commands that `sync-env` runs belong in `--dry` only.
5. **Jakob's Law.** Follow terminal conventions: honor `NO_COLOR`, send errors to stderr, and color diffs as git does.

## Design system

- **Style guide:** This file.
- **Tokens:** `lib/style.sh` (not written yet). Until it exists, the closest thing is the `C_*` variables in `commands/doctor/doctor`.

### Rules

- **Use only the 16 basic ANSI colors and the attributes** (bold, dim, reverse). The terminal theme sets their real colors, so the output fits every theme. Never use 256-color or truecolor codes.
- **Use `dim` for muted text, not bright black.** Bright black is almost the background color in some dark themes.
- **Use semantic variables in commands.** A command uses only the variables from `lib/style.sh`, such as `$STYLE_OK`, and never writes a raw escape code. The variables are empty when stdout is not a terminal or `$NO_COLOR` is set.
- **Add a new semantic variable only when the user approves it.**

### Output layout

- **Status words.** A result is one line: a status word in a fixed-width colored column, a label, and an optional detail. Use ASCII words, never symbols, so that the output reads the same without color. Each word belongs to one semantic color:

  | Variable      | Meaning                     | Words                                   |
  | ------------- | --------------------------- | --------------------------------------- |
  | `STYLE_OK`    | it worked                   | `ok`, `copied`, `ran`                   |
  | `STYLE_WARN`  | needs a look or a decision  | `warn`, `drift`                         |
  | `STYLE_FAIL`  | broken                      | `FAIL`                                  |
  | `STYLE_MUTED` | nothing happened            | `same`, `skipped`, `not run`, `pending` |
  | `STYLE_INFO`  | information, with no verdict | `tunable`, `info`, `copy` (dry run)    |

- **Sections.** A group starts with a blank line and its name in bold. Do not use lines of dashes.
- **Summary.** Every command ends with a blank line, then a table of results if it has one (for `setup`, every step with its status and time), then one verdict line. The verdict line gives the counts, in the color of the worst status.
- **Dry runs.** Print one header line, `Dry run: nothing changes`, then the normal status lines. The raw commands are muted and indented under their status line.
- **Errors.** Usage and fatal errors go to stderr as `<command>: <message>`, without color.
- **Progress.** A spinner is allowed only on a terminal, and only while work runs. When the work ends, a status line replaces the spinner.
