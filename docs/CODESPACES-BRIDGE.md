# docs/CODESPACES-BRIDGE.md (v0.2)

## Purpose
Ensure “Create codespace” at repo root uses a working configuration (default **webtop**) and exposes other variants via the picker, while keeping real devcontainer payloads under `workspaces/<variant>/.devcontainer`.

## Files
- `.devcontainer/devcontainer.json` → default (webtop) delegating to `../workspaces/webtop/.devcontainer/compose.yaml` and hooks under `workspaces/webtop/`.
- `.devcontainer/webtop/devcontainer.json` → picker profile for webtop.
- `.devcontainer/novnc/devcontainer.json` → picker profile for novnc.

## Behavior
- Default codespace = webtop.
- “Configure and create” shows **webtop**/**novnc** options.
- All profiles mount repo root to `/workspaces` so subfolder workspaces can access shared materials.

---
