# docs/REGRESSION-CHECKS.md (v0.2)

**Features**
- Validate JSON schema.
- Build ephemeral container; run `install.sh`; assert binary presence and versions.

**Templates**
- Materialize to temp; `devcontainer build` must pass.

**Workspaces (each variant)**
- Build success.
- Health probes:
  - `curl -fsSL http://localhost:9222/json/version` returns JSON.
  - Desktop reachable (`3001` webtop / `6080` novnc).
  - `redis-cli -h 127.0.0.1 -p 6379 PING` → `PONG`.
  - Optional: `supabase start`; Studio on `54323`.
- No files under `/apps` in Git history.

**Codespaces root bridge**
- Default config (webtop) works from repo root.
- Picker lists both `webtop` and `novnc` configs.

---
