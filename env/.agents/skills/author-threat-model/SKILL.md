---
name: author-threat-model
description: Write or update a threat model for a whole product, or for one feature. The code-review skill checks every change against it.
disable-model-invocation: true
---

Write a threat model that answers the four questions: what are we working on, what can go wrong, what are we going to do about it, and did we do a good job. The Security axis of the `code-review` skill reads it on every review, so write its **security invariants** as statements that a reviewer can check against a diff.

## Files

```
docs/threat-model/
├── product.md          ← the whole product: one per repo
└── <feature>.md        ← one feature, in the context of product.md
```

Use the format in [THREAT-MODEL-FORMAT.md](THREAT-MODEL-FORMAT.md) for both. A feature model records only what the feature adds or changes, and refers to the product model's IDs for the rest.

## Process

### 1. Pick the scope

Ask the user whether this is the **product** model or a **feature** model, unless they already said. For a feature, get its spec or description, and the slug for its file name.

If the target file exists, this is an update: read it, and change it in place. If a feature model is asked for and `product.md` is missing, tell the user. Offer to write the product model first, and if they decline, record the product-level assumptions that the feature depends on in the feature model.

### 2. Map the system

Explore the code (and, for a feature, its spec) until you can fill in **Scope**, **Assets**, **Actors**, **Entry points**, **Trust boundaries**, and **Data flows**. The map is done when every entry point in scope is listed, and every data flow that crosses a trust boundary is drawn.

Read the deployment and the configuration too: CI workflows, container and infrastructure files, and the dependency manifests. Attackers use these as entry points.

### 3. Fill the gaps with the user

Ask about what the code cannot show, one question at a time, each with your recommended answer:

- Who are the adversaries in scope, and who is explicitly out of scope?
- Which assets matter most, and what is the worst outcome for each one?
- Compliance and data-handling obligations.
- Deployment facts that the repo does not hold (network exposure, identity provider, secrets store).

### 4. Enumerate threats

Apply **STRIDE** (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege) to every trust-boundary crossing in the data flows. For a feature that sends data to or from an LLM, also apply prompt injection, insecure output handling, and excessive agency. For each threat, record the threat, its likelihood and impact, its mitigation, and the module where the mitigation is enforced.

Do not invent mitigations: a threat with no control in the code is `open`. The enumeration is done when every crossing has had every STRIDE category applied, and each category has a threat or a one-line reason that it does not apply.

### 5. Decide each threat with the user

Present the threats that are `open` or `planned`, ordered by risk, and ask the user to decide each one: mitigate now, plan (with a link to an issue), or accept. Only the user accepts a risk; record their reason with the acceptance.

### 6. Write the invariants

Turn every mitigation into a **security invariant**: one checkable statement about the code, such as "Every route under `/admin` checks the `admin` role on the server". A reviewer must be able to look at a diff and say whether it keeps the invariant.

### 7. Write the file

Write the model to its file in the format. Set **Last reviewed** to today's date.

The model is done when every entry point and trust boundary is in it, every threat has a status, every accepted risk has the user's reason, and every `mitigated` threat names an invariant.
