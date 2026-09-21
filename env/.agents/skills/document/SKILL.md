---
name: document
description: Use to write technical documentation.
metadata:
  author: domtriola
---

When writing documentation follow these standards:

## Standards

### 1. Up to date

The only thing worse than missing documentation is stale documentation. I'd rather not know something than be told something false.

Make sure that documentation accurately reflects the project it describes.

### 2. No duplication

Nothing should be explained twice. It is hard enough to keep one source of documentation up to date. If in doubt, keep more elaborate documentation closer to the source of what it's documenting and provide a link to that documentation in higher level docs.

The higher-level the readme, the higher the ratio of links:copy should be.

### 3. Prefer brevity and conciseness

Documentation should give an overview of the landscape, rather than 

### 4. Use simple language

Use ASD-STE100 Simplified Technical English.
Avoid jargon and phrasing that could be misleading.
Be grammatically correct.
Use full sentences.
Never use em dashes.

### 5. Be precise

Don't over-simplify concepts with phrases like "that's the whole difference" or "that's the whole point". Most things are nuanced. State the nuances plainly when they matter and don't use hyperbole.

### 6. Be consistent with context

Write in the third person and don't use personal pronouns.

Never explain something that was a passing thought process. For example, don't leave a comment saying "...so it needs no notes here" or "...was removed because it was deprecated" after removing a reference to something.

### 6.1 Comments describe the present, in their own scope

A comment is read by someone looking at this code now. It is not a changelog, a migration note, or a record of how the code came to be.

Do not write:

- What the code used to do, or what a previous approach was.
- Why an earlier attempt was abandoned, or that a bug once existed.
- What another file did, does, or asks, when the reader does not need it to understand this code.
- A justification that only makes sense to someone who watched the change happen.

Do write, when the code cannot say it itself:

- A constraint that is not visible here, such as an ordering requirement or an external limit.
- A consequence a reader would not predict.
- A failure mode, and what it looks like.

Name another file only when this code cannot be understood without it, and then state the constraint as it is today rather than how it was discovered. "The interface does not exist on a first run, so the address is set later" is a constraint. "This was tried in the other script and did not work" is history.

Prefer no comment to an implementation/context loaded one that will likely grow stale. A missing comment leaves a reader with a question. A historical or entangled comment gives them a wrong model of the system, which they have to unlearn before the question can even be asked.

The same line of code, with three comments. Only the last one earns its place:

```bash
# Bad. History, and another file's business. The reader has to open a second
# file to understand a line that did not need explaining.
#
# The retry count used to be hard-coded here. It moved into a setting when the
# deploy script started needing a different value, and that script sets it
# before calling this one.
retries="${UPLOAD_RETRIES:-3}"

# Bad. Restates the code. A reader who can read the line learns nothing, and
# now has two things to keep in step instead of one.
#
# Default the retry count to three.
retries="${UPLOAD_RETRIES:-3}"

# Good. States what the number encodes, which the code cannot show. A reader
# who wants to raise it can see why that would not help.
#
# The upstream rate limiter rejects a fourth attempt inside its window, so a
# higher value only adds delay before the same failure.
retries="${UPLOAD_RETRIES:-3}"
```

### 6.2 When reviewing, delete more than you add

Reviewing a comment has three useful outcomes: delete it, cut it to the one sentence that carries a constraint, or leave it alone. Rewriting it at the same length is rarely one of them.

Default to deletion. A comment that needs a long argument to justify keeping it has already answered the question.

**The test.** Ask what the comment lets a reader do that the code does not. Good answers: avoid a trap, predict a consequence, recognise a failure when it happens. A bad answer, and the most common one: understand why the author chose this.

**Smells that mean delete.**

- Instructions for a reader to follow. Those belong in a README, and repeating them here breaks the rule against duplication.
- A description of the code's own defensiveness, such as "the missing case is handled rather than assumed". The branch below already shows it.
- More than one paragraph arguing for a single choice.
- A sentence about another component that a reader does not need in order to follow this code.

**Length is a liability.** Every extra sentence encodes more context, and context goes stale on its own schedule, separately from the code. A short comment is more likely to still be true in a year.

The same block, before and after a review:

```yaml
# Before. Four sentences, one of which is a constraint.
#
# The token is required rather than defaulted, and that is deliberate: a
# credential does not belong in a file that can be published. The installer
# validates arguments before it builds anything, so a missing value stops the
# build with a message instead of producing something that fails later on.
# Supply it on the command line, or put it in the credentials file, which the
# wrapper passes automatically.
token:
  required: true

# After. The constraint, and nothing else. Where to put the value is a README's
# job, and how the installer validates it is the installer's.
#
# Required rather than defaulted: a credential does not belong in a file that
# can be published.
token:
  required: true
```

### 7. Documentation should be extensible

Don't hard-code documentation details. Well-written code allows for extension. Documentation should do the same. For example, instead of saying "these 5 scripts: ...list", just say "these scripts: ...list".
