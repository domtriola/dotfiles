# Security review

The brief for the Security axis of the `code-review` skill. Review the diff as an attacker who has read the threat model.

## 1. Load the threat model

Read every threat model and security doc you were given. From them, note:

- The **assets**, **actors**, and **trust boundaries**.
- The **security invariants**: the statements every change must keep true. These are your primary standard, in the same way that documented rules are for the Standards axis.
- The **threats** with status `mitigated`, and the control that mitigates each one. A diff that weakens one of these controls reopens the threat.
- The **accepted risks**. Do not report these again unless the diff makes them worse.

If you were given "no threat model", infer the trust boundaries from the code (network handlers, CLI arguments, files, environment, third-party APIs, model output), say so at the top of the report, and use the baseline below as your only standard.

## 2. Trace the diff

For each hunk, trace **untrusted input** from where it enters (a source) to where it has an effect (a sink: a query, a shell, a file path, an HTML page, a URL fetch, a deserializer, a prompt, an authorization decision). A finding needs a path from a source that an attacker controls to a sink, with no control between them.

Read the deleted lines as carefully as the added ones. A removed check, a loosened permission, or a deleted test of a control is a finding.

## 3. Check the baseline

Apply every item below to the diff. The repo's threat model overrides this list where they disagree.

**OWASP Top 10 (2025)**:

1. [A01:2025 - Broken Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/): a missing authorization check on a new route or action, object access by a caller-supplied ID (IDOR), authorization enforced only on the client, SSRF.
1. [A02:2025 - Security Misconfiguration](https://owasp.org/Top10/2025/A02_2025-Security_Misconfiguration/): debug modes, permissive CORS, missing security headers, insecure defaults, broad file or container permissions.
1. [A03:2025 - Software Supply Chain Failures](https://owasp.org/Top10/2025/A03_2025-Software_Supply_Chain_Failures/): new or changed dependencies, unpinned versions, lockfile changes that do not match the manifest, install scripts, `curl | sh`, CI actions not pinned to a commit SHA.
1. [A04:2025 - Cryptographic Failures](https://owasp.org/Top10/2025/A04_2025-Cryptographic_Failures/): custom cryptography, weak algorithms, non-random IVs or salts, predictable randomness for tokens, secret comparison that is not constant-time, sensitive data stored or sent without encryption.
1. [A05:2025 - Injection](https://owasp.org/Top10/2025/A05_2025-Injection/): SQL, shell, path traversal, template, HTML (XSS), header, and log injection.
1. [A06:2025 - Insecure Design](https://owasp.org/Top10/2025/A06_2025-Insecure_Design/): a design that cannot hold an invariant, however carefully it is coded; missing rate limits on costly or sensitive actions.
1. [A07:2025 - Authentication Failures](https://owasp.org/Top10/2025/A07_2025-Authentication_Failures/): session handling, token lifetime and revocation, password storage, account recovery.
1. [A08:2025 - Software or Data Integrity Failures](https://owasp.org/Top10/2025/A08_2025-Software_or_Data_Integrity_Failures/): unsafe deserialization, unsigned updates or artifacts, trust in data that the client can change.
1. [A09:2025 - Security Logging and Alerting Failures](https://owasp.org/Top10/2025/A09_2025-Security_Logging_and_Alerting_Failures/): security events with no log, and logs that hold secrets, tokens, or personal data.
1. [A10:2025 - Mishandling of Exceptional Conditions](https://owasp.org/Top10/2025/A10_2025-Mishandling_of_Exceptional_Conditions/): a control that fails open, errors that leak internals, partial state after a failure.

**Also check**:

- **Secrets**: keys, tokens, passwords, or private URLs in code, config, tests, fixtures, or commit messages.
- **CI and automation**: workflow triggers that run untrusted code with secrets (for example `pull_request_target`), and untrusted event fields expanded into a shell (`${{ github.event.* }}`).
- **LLM and agent features**: untrusted content that reaches a prompt (prompt injection), model output that reaches a sink without validation, and tools or permissions broader than the task needs (excessive agency). Agent instructions, such as skills and `AGENTS.md`, run with the agent's permissions: treat a change to them as a change to code.
- **Resource exhaustion**: unbounded input size, loops, recursion, or fan-out driven by an attacker.

## 4. Check for threat-model drift

Report **drift** when the diff adds an entry point, asset, actor, trust boundary, or data flow that the threat model does not describe, or changes a control that a `mitigated` threat names. Drift is a finding even when the code is safe, because the model no longer describes the system.

## 5. Report

Report each finding with:

- **Severity**: `critical`, `high`, `medium`, or `low`, from the impact on the assets and the effort that the attack needs.
- **Location**: the file and the quoted hunk.
- **Reference**: the threat ID or invariant from the threat model that it breaks, else the baseline item.
- **Exploit**: one or two sentences: which actor does what, across which boundary, to get what.
- **Fix**: the smallest change that closes the path.

Report only findings with a concrete exploit path. Put a suspicion that you cannot complete into a short **Questions** list. Report drift in its own **Threat-model drift** list. Skip what tooling already enforces. Under 500 words.
