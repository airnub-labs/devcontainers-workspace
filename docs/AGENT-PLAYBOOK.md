# docs/AGENT-PLAYBOOK.md (v0.2)

## Create a new workspace variant
1. `mkdir -p workspaces/<name>/.devcontainer`.
2. Seed from `templates/classroom-studio-webtop/.template/.devcontainer/`.
3. Adjust compose (swap GUI sidecar, ports, labels); keep `dev` + `redis`.
4. Add `workspace.blueprint.json`, `postCreate.sh`, `postStart.sh`, and `<name>.code-workspace`.
5. Build & health-check; document in `docs/WORKSPACE-ARCHITECTURE.md`.

## Update a feature
1. Edit `features/<id>/devcontainer-feature.json` option schema + `install.sh`.
2. Update `features/<id>/README.md` and `docs/CATALOG.md`.
3. Run feature tests.

## Sync workspace from template
1. Copy template payload into `workspaces/<variant>/.devcontainer/`.
2. Restore variant-specific deltas.
3. `devcontainer build`; open PR with summary + checklist.

## Add a CLI to `agent-tooling-clis`
1. Add option flag in schema; implement conditional install.
2. Update docs; ensure idempotency.

## Pin image digest
1. Replace tag with `@sha256:…` in compose; add to `docs/CATALOG.md` matrix.

---
