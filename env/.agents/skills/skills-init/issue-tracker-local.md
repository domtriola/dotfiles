# Issue tracker: local Markdown

Specs, tickets, and maps for this repo are Markdown files in `docs/`, committed with the code.

## Specs

- **Publish**: write `docs/specs/<slug>.md`, where `<slug>` is a short kebab-case name for the feature, and commit it.
- **Fetch**: read the file at the path the user gives, or the spec whose slug matches the feature or the branch name.
- **Close**: delete the spec file and its ticket directory in the PR that implements it. Git history keeps them. Before you delete them, move anything that must outlive the spec into `GLOSSARY.md` or an ADR.

## Tickets

- **Publish**: write one file per ticket at `docs/specs/<slug>/<NN>-<ticket-slug>.md`, numbered from `01` with blockers first, and commit them. Put a `Status: ready-for-agent` line at the top of each file.
- **Blocking**: a `Blocked by: <NN>, <NN>` line at the top of the file, or `Blocked by: none`.
- **Frontier**: the ticket files that do not have `Status: done` and whose blockers all have `Status: done`. A frontier ticket is unclaimed when it has `Status: ready-for-agent`. Take the unclaimed one with the lowest number.
- **Claim**: set `Status: claimed` before any other work.
- **Close**: set `Status: done`.

## Maps

The `wayfinder` skill uses these operations.

- **Map**: `docs/maps/<effort>/map.md`.
- **Map ticket**: `docs/maps/<effort>/<NN>-<slug>.md`, numbered from `01`, with a `Type: <type>` line, a `Status: open` line, and a `Blocked by:` line as for tickets.
- **Frontier**: the map tickets that do not have `Status: resolved` and whose blockers all have `Status: resolved`. A frontier ticket is unclaimed when it has `Status: open`. Take the unclaimed one with the lowest number.
- **Claim**: set `Status: claimed` before any other work.
- **Resolve**: add the answer under an `## Answer` heading, set `Status: resolved`, then add a line to "Decisions so far" in `map.md`.

## Triage

The `triage` skill needs the GitHub tracker. This repo does not support it.
