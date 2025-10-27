# docs/WORKSPACE-ARCHITECTURE.md (v0.2)

## Overview
The **Workspaces** area hosts multiple **variants**, each with its own `.devcontainer/` and `.code-workspace`. A **root `.devcontainer` bridge** lets Codespaces pick a default (webtop) or select another (novnc) at creation time.

```
workspaces/
  webtop/
    .devcontainer/
    airnub-webtop.code-workspace
    workspace.blueprint.json
    postCreate.sh
    postStart.sh
  novnc/
    .devcontainer/
    airnub-novnc.code-workspace
    workspace.blueprint.json
    postCreate.sh
    postStart.sh
  _shared/
    supabase/
apps/           # cloned on demand; ignored by Git
.devcontainer/  # root bridge: default + picker profiles
```

### Mounts
All variants mount the repo root into the container even when opened from a subfolder:

```json
{
  "workspaceMount": "source=${localWorkspaceFolder}/../..,target=/workspaces,type=bind,consistency=cached",
  "workspaceFolder": "/workspaces"
}
```

### Services & Ports
- `dev` primary: Node 24 + pnpm + CLIs; **CDP 9222**.
- `redis` sidecar: **6379**.
- GUI sidecar per variant: `webtop` (**3001**) or `novnc` (**6080**, audio optional **6081**).
- Supabase Studio (via CLI): **54323** when started.

### Dynamic projects (blueprint)
`workspace.blueprint.json` defines repos to clone into `/apps` during `postCreate`. Workspaces’ `*.code-workspace` points generically to `/apps`, so no edits are needed when repos change.

### Security & isolation
- No secrets in Git; consume Codespaces/Actions secrets.
- Avoid privileged containers; prefer sidecars.

---
