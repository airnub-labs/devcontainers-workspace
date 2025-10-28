# Migration Guide

1. **Retire legacy `.devcontainer/scripts` installers.** Supabase, Codex, Claude, Gemini, Docker, and CUDA setup scripts now live under `features/*`. Workspace-specific logic belongs in `workspaces/<variant>/postCreate.sh` or `postStart.sh`.
2. **Adopt templates.** Instead of copying `.devcontainer` folders between projects, consume the templates from this repository (via `devcontainer templates apply airnub-labs/web`, etc.). Options cover Supabase project refs, Chrome CDP ports, and Next.js scaffolding.
3. **Move GUI browsers to sidecars.** Desktop/noVNC tooling is isolated in the `classroom-studio-webtop` template. The primary container stays lightweight and headless.
4. **Pre-clone required repositories.** Templates now declare `customizations.codespaces.repositories` blocks for Codespaces and ship `.devcontainer/workspace.repos.yaml` manifests plus a `scripts/ws-clone` helper for local/CLI parity.
5. **Rename `mcp-clis` → `agent-tooling-clis`.** Update any pinned references (`features/agent-tooling-clis`) and switch template options or overrides from `includeMcpClis` to `includeAgentToolingClis`.
6. **Use prebuilt images for faster startups.** Both `web` and `nextjs-supabase` templates default to `ghcr.io/airnub-labs/dev-web:<version>`. Opt out with the `usePrebuiltImage` option if you need local Dockerfile tweaks.
7. **Wire up CI.** The new GitHub Actions workflows publish features, build GHCR images, validate templates, and run `.score/scripts/checks.sh` for spec conformance. Mirror the workflow configuration into downstream repositories or trigger them via reusable workflows.
