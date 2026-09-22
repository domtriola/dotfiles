# pi-copilot

**Proof of concept.** A sandbox kit for the [pi](https://pi.dev) coding agent,
pointed at the GitHub Copilot inference endpoint instead of at a model provider
of its own.

The kit answers one question, and the answer is written to
`~/.pi-copilot-kit.log` on the first start: **does the Copilot endpoint serve a
client that identifies itself honestly?** Read
[What is unresolved](#what-is-unresolved) before you use this for real work.

Why Copilot rather than an Anthropic subscription is in
[`docs/pi-copilot.md`](../../../../docs/pi-copilot.md).

## Pre-setup

Create a **user-owned fine-grained personal access token** with the
`Copilot Requests` permission, then bind it on the host:

```console
sbx secret set copilot
```

Three things about that token, each of which produces a different failure:

- It has to be **fine-grained**. A classic PAT cannot carry the permission.
- Its resource owner has to be **your user account**. `Copilot Requests` is an
  account-level permission, so it is hidden from the form when an organisation
  is the owner.
- The permission is under **Account permissions**, not repository permissions,
  and `Read` is the level to set.

GitHub documents this token for its own Copilot CLI, which reads it from the
same `COPILOT_GITHUB_TOKEN` variable this kit declares. See
[Authenticating GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli).

The credential is `required: true`, so `sbx` refuses to create the sandbox when
nothing is bound. That is deliberate. The upstream `pi` kit's README describes
the alternative: an unbound sandbox still receives the sentinel, pi cannot tell
it from a real token, and the first model call returns a bare `401` that reads
like a wrong key rather than a missing one.

## Quick start

```console
sbx run ./sbx/kits/sandboxes/pi-copilot
```

Then read the log inside the sandbox:

```console
sbx exec <sandbox-name> -- cat /home/agent/.pi-copilot-kit.log
```

## Configuration

| Input                    | Kind     | Meaning                                                                    |
| ------------------------ | -------- | -------------------------------------------------------------------------- |
| `copilotHost`            | kit arg  | Copilot inference host. Defaults to the Pro and Pro+ one.                  |
| `copilotIntegrationId`   | kit arg  | The `Copilot-Integration-Id` header. Defaults to `pi`.                     |
| `modelIds`               | kit arg  | Pins the model list. Empty asks the endpoint, which is the usual.          |
| `COPILOT_BASE_URL`       | variable | Built from `copilotHost`. Override to point elsewhere.                     |
| `COPILOT_INTEGRATION_ID` | variable | Built from `copilotIntegrationId`.                                         |
| `MODEL_IDS`              | variable | Built from `modelIds`.                                                     |

The host per plan:

| Plan                | Host                                |
| ------------------- | ----------------------------------- |
| Copilot Pro, Pro+   | `api.individual.githubcopilot.com`  |
| Copilot Business    | `api.business.githubcopilot.com`    |
| Copilot Enterprise  | `api.enterprise.githubcopilot.com`  |

Set it with the same file `pi-ailo` uses:

```console
printf 'copilotHost=%s\n' 'api.business.githubcopilot.com' >>~/.config/sbx/kit.args
```

Two setup steps, both scripts rather than commands inside `spec.yaml`:

| Script                                  | When            | What                                     |
| --------------------------------------- | --------------- | ---------------------------------------- |
| `files/home/.pi-copilot-kit/install.sh` | once, at create | Points npm at the sandbox proxy.         |
| `files/home/.pi-copilot-kit/startup.sh` | every start     | Probes the endpoint, renders pi's config. |

## How the credential works

The kit declares one `copilot` service credential with `proxyManaged: true`, so
`COPILOT_GITHUB_TOKEN` inside the sandbox holds a sentinel and not a token. pi
interpolates that variable into the provider's `apiKey` and sends it as
`Authorization: Bearer`. The sandbox proxy replaces the header on egress to a
Copilot host. The real token never enters the container, so it is not readable
by the agent or by anything the agent runs.

Nothing here performs a token exchange, and nothing reads a signed-in editor's
credentials. The token is one you minted for this purpose and can revoke on its
own.

The credential injects into all four Copilot hosts, and all four are allowed,
because argument interpolation is proven inside `permissions` and `environment`
and is not yet proven inside a `credentials` block. Narrowing both lists to the
single host named by `copilotHost` is the first cleanup once that is confirmed.

## What is unresolved

**The credential is documented. The endpoint is not.** GitHub documents the
`Copilot Requests` token and tells you to put it in `COPILOT_GITHUB_TOKEN`. It
does not document `/chat/completions` or `/models` on the Copilot hosts. The
only published Copilot REST API covers seat and billing management. So the
token is sanctioned and the destination is an internal interface that may
change or close without notice.

**The kit identifies itself truthfully, and that may be why it fails.** The
endpoint reads `Copilot-Integration-Id` and `Editor-Version` to decide which
client is asking. Every third-party tool in this space sends an editor's
values. This kit sends its own name. If the probe returns `403`, that is the
endpoint saying the interface is for GitHub's own editors, which is a real
answer and worth having.

**Do not resolve a `403` by copying an editor's integration id.** It would turn
a kit that uses a documented token against an undocumented endpoint into a kit
that misrepresents what it is. The first is a gap in GitHub's documentation.
The second is the thing GitHub's community answers actually object to.

**The volume clauses apply.** Section H of the GitHub Terms of Service reserves
suspension of API access for "abuse or excessively frequent requests", at
GitHub's sole discretion, after a reasonable attempt to warn by email. The
Acceptable Use Policies prohibit "excessive automated bulk activity". A coding
agent in a loop is the traffic shape those clauses describe, and requests are
billed against the premium request allowance of the account that owns the
token.

**Whether the proxy sets or adds the header is untested.** The credential and
pi both target `Authorization`. If the proxy appends rather than replaces, the
request carries two, and Copilot will refuse it. The probe in `startup.sh`
sends the header itself, so the log distinguishes this from a bad token.

## If it does not answer

Read `~/.pi-copilot-kit.log`. The startup hook records the host it used, the
integration id it sent, the status code, and what each code means:

| Code  | Meaning                                                                 |
| ----- | ----------------------------------------------------------------------- |
| `200` | The endpoint served this client. The model list follows in the log.     |
| `401` | The token was rejected. Wrong kind, wrong owner, missing permission, or expired. |
| `403` | The token is valid and the client was refused. See above.               |
| `404` | Wrong host for the plan, or the path moved.                             |
| `000` | No answer. A network policy or routing fault. `sbx policy log` names it. |
