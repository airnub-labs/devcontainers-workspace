# docs/TEMPLATE-SYNC.md (v0.2)

## Manual sync
1. Pick template tag/version (e.g., `classroom-studio-webtop@1.3.0`).
2. Copy `.template/.devcontainer/*` → `workspaces/<variant>/.devcontainer/`.
3. Re-apply variant deltas (GUI service, ports).
4. Rebuild; run regression checks; commit with `chore(workspaces): sync <variant> with template vX.Y.Z`.

## Optional GitHub Action (sketch)
- Trigger: changes in `templates/classroom-studio-webtop/.template/.devcontainer/**`.
- Job: for each `workspaces/*`, open PR with updated payload + run smoke tests (ports, CDP, Redis, Studio when started).

---
