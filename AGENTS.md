# AGENTS.md — Guardrails


## Invariants
1) Keep `.devcontainer/` materialized from the catalog template.
2) No secrets in repo. Use Codespaces/Repo secrets.
3) Idempotent hooks (`postCreate`, `postStart`).
4) Ports and sidecars must match the chosen stack README.


## Taxonomy
- Feature = install-only
- Template = multi-container payload
- Image = prebuilt base
- Stack = Template flavor in the catalog
- Meta Workspace = this repo (consumer)
