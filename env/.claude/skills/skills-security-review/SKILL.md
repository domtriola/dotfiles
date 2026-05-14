---
name: skills-security-review
description: Use when auditing skills from external sources, plugin repositories, or untrusted contributors before installation — specifically to find agent instructions that could cause unsafe autonomous actions
---

# Skills Security Review

## Overview

Review skill files for instructions that cause an agent to take unsafe autonomous actions. The threat model is **second-order**: even with a trusted invoking user, skills may process content from third parties (competitor sites, customer uploads, scraped data) who are not trusted.

## Process

### Step 1: Enumerate

```bash
find <skills-dir> -name "SKILL.md" -o -name "*.md" | sort
```

Read every file. Don't sample — gaps in coverage miss real issues.

### Step 2: Flag by Category

| Category | Pattern to find | Severity |
|----------|----------------|----------|
| Code execution from untrusted data | Instructions to generate **and run** scripts where input comes from uploads, web scrapes, or third-party APIs | HIGH |
| Safety bypass | "ignore previous instructions", override system prompt, disable safety | HIGH |
| Data exfiltration | Sending user data to external URLs not disclosed to the user | HIGH |
| Document-as-instructions | Treating uploaded file content as agent commands rather than data to analyze | HIGH |
| URL fetch — user-supplied | Fetching a URL the user provides as an argument | MED |
| URL fetch — external search | Browsing sites found via web search results | MED |
| Auto file write | Writing files without an explicit user confirmation step | MED |
| User-controlled filenames | Filenames derived from user input or document content (path traversal: `../../`) | MED |

### Step 3: Apply Trust Filter

Before reporting, ask: **does this finding survive the trusted-user assumption?**

- Agent running code *the user asked for* on *the user's own data* → reduce to LOW
- Agent running code where *data source is a third party* (customer feedback CSV, scraped competitor page) → stays HIGH
- Fetching URLs the user supplies where site content is adversarial → stays MED
- Auto file writes to user's own workspace → reduce to LOW with trusted user
- Safety bypasses, exfiltration, document-as-instructions → HIGH regardless of trust

### Step 4: Report

```
**[HIGH]** `path/to/SKILL.md:NN` — exact quoted instruction, why it's unsafe
**[MED]**  `path/to/SKILL.md:NN` — exact quoted instruction, condition under which it matters
**[LOW]**  `path/to/SKILL.md` — note only if not already covered above

No issues found in: [list clean files]
```

End with a one-sentence **Bottom Line** on overall risk level.

## Common False Positives

| Looks bad | Why it's usually fine |
|-----------|-----------------------|
| "Generate a Python script" | Risk only if skill also says to *run* it |
| "Read uploaded CSV" | Reading ≠ execution; flag only if data influences code that executes |
| "Use web search" | Low risk unless search results are treated as instructions |
| "Save as markdown" | Fine unless filename is derived from user-controlled input |
