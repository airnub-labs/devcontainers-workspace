# Migration Guide

1. **Replace legacy `.devcontainer/scripts` installers.** Supabase, Codex, Claude, Gemini, Docker, and CUDA setup scripts now live under `features/*`. Remove bespoke shell hooks and reference the published features in `devcontainer.json`.
2. **Adopt templates.** Instead of copying `.devcontainer` folders between projects, consume the templates from this repository (via `devcontainer templates apply airnub-labs/web`, etc.). Options cover Supabase project refs, Chrome CDP ports, and Next.js scaffolding.
3. **Move GUI browsers to sidecars.** Desktop/noVNC tooling is isolated in the `classroom-studio-webtop` template. The primary container stays lightweight and headless.
4. **Use prebuilt images for faster startups.** Both `web` and `nextjs-supabase` templates default to `ghcr.io/airnub-labs/dev-web:<version>`. Opt out with the `usePrebuiltImage` option if you need local Dockerfile tweaks.
5. **Wire up CI.** The new GitHub Actions workflows publish features, build GHCR images, and validate templates. Mirror the workflow configuration into downstream repositories or trigger them via reusable workflows.
