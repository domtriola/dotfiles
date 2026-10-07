# Threat model format

Use this format for `docs/threat-model/product.md` and for each feature model. Give every row a stable ID (`A1`, `B1`, `T1`, `I1`), and never reuse an ID after you delete its row: reviews and issues refer to them. A feature model prefixes its IDs with its slug (`export-T1`), and refers to product IDs as they are.

Describe modules by name. Give a file path only for an entry point or a control that a name cannot find.

<threat-model-template>

# Threat model: <product or feature name>

**Kind**: product | feature
**Product model**: <link to product.md; feature models only>
**Origin**: <link to the issue or PR that introduced the feature; feature models only>
**Last reviewed**: <YYYY-MM-DD>

## Scope

What this model covers: the modules, entry points, and deployments. The `code-review` skill uses this section to decide whether a diff falls under this model. Also list what is out of scope, and why.

## Assets

| ID  | Asset | Why it matters | Worst outcome |
| --- | ----- | -------------- | ------------- |

## Actors

Legitimate users, operators, third-party services, and adversaries. For each adversary, state what they can already do (for example: "anonymous user on the internet", "authenticated tenant", "maintainer of a dependency").

## Entry points

Every place that data or commands enter the system: routes, CLI arguments, files read, environment, queues, webhooks, CI triggers, and model output.

## Trust boundaries

| ID  | Boundary | Between | Control at the boundary |
| --- | -------- | ------- | ----------------------- |

## Data flows

A Mermaid `flowchart` of the flows that cross a trust boundary, with each boundary drawn as a `subgraph`. Label each edge with the data it carries.

## Threats

| ID  | STRIDE | Threat | Boundary | Likelihood | Impact | Status | Mitigation |
| --- | ------ | ------ | -------- | ---------- | ------ | ------ | ---------- |

- **Likelihood** and **Impact**: `low`, `medium`, or `high`.
- **Status**: `mitigated` (name the invariant), `planned` (link the issue), `accepted` (see below), or `open`.

## Security invariants

The statements that every change must keep true. The `code-review` skill checks each diff against this list.

| ID  | Invariant | Enforced in | Mitigates |
| --- | --------- | ----------- | --------- |

## Accepted risks

| Threat | Reason | Accepted by | Date | Revisit when |
| ------ | ------ | ----------- | ---- | ------------ |

## Assumptions

Facts the model depends on that the code does not show, such as "TLS ends at the load balancer". A change that breaks an assumption invalidates the model.

</threat-model-template>
