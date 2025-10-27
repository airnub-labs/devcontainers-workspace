# Classroom & Studio Setup

1. Choose the `classroom-studio-webtop` template for courses that rely on touch devices or iPad-based debugging. The template launches a Codespaces-friendly primary container (`dev`) alongside a `webtop` sidecar that exposes a full desktop over HTTPS.
2. Forward the configured `webtopPort` (default `3001`) to access the remote desktop via the Codespaces ports panel. Chrome runs inside the sidecar and inherits any managed policies mounted from `.devcontainer/policies`.
3. Use the `policyMode` option when applying the template:
   - `none` keeps Chrome un-managed (best for experimentation).
   - `managed` mounts the selected policy JSON into the sidecar to enforce signin/tabs/password defaults for students.
4. The primary container ships with the Supabase CLI (with helper wrappers) and optional agent tooling CLIs for Codex/Claude/Gemini. Supply API keys via Codespaces secrets or `.env` files after the container boots. Add MCP server connections per project using `.devcontainer/postCreate.sh` (or editor project settings) so every workspace configures the same endpoints on first launch.
