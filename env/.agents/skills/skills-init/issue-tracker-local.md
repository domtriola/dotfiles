# Issue tracker: local Markdown

Specs for this repo are Markdown files in `docs/specs/`, committed with the code.

- **Publish**: write `docs/specs/<slug>.md`, where `<slug>` is a short kebab-case name for the feature, and commit it.
- **Fetch**: read the file at the path the user gives, or the spec whose slug matches the feature or the branch name.
- **Close**: delete the spec file in the PR that implements it. Git history keeps it. Before you delete it, move anything that must outlive the spec into `GLOSSARY.md` or an ADR.
