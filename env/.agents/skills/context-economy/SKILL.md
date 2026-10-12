---
name: context-economy
description: Keep the session context small while you explore, edit, and format code. Use before you read code across many files, and in any long task, such as implementing, debugging, or writing a spec.
---

Every turn reads the whole context again, so text that enters it early costs on every later turn.

- **Explore through a sub-agent.** When you must read more than three or four files to learn the code, give the reading to a sub-agent (an `Explore` agent, if there is one) and ask it for paths, signatures, and facts, not file contents. If you cannot dispatch a sub-agent, read only the parts of each file that you need. Read a whole file only when you will edit it.
- **Edit with small, exact replacements** in the edit tool. A whole-file rewrite through a script or a heredoc enters the context once in the call, and again when the harness reports the change.
- **Format once, at the end.** Run the formatter on the changed files only, just before the commit. A formatter run over the whole repo changes files that you read, and the harness reports each of them again.
