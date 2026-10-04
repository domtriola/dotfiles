---
name: research
description: Research a question in primary sources and write the findings to a Markdown file in the repo.
disable-model-invocation: true
---

Dispatch a background sub-agent to do the research, so you can keep working while it reads. If you cannot dispatch one, do the research yourself.

The research:

1. Investigate the question in **primary sources**: official docs, source code, specs, and first-party APIs. Trace every claim back to the source that owns it, past any secondary write-up.
2. Write the findings to one Markdown file, and cite the source of each claim.
3. Save the file where the repo already keeps such notes. If the repo has no convention, choose a location and tell the user where.

The work is done when the file exists and every claim in it cites a primary source.
