# Versioning Strategy

- Features follow semantic versioning even though they are consumed locally via `features/<feature>`. Update the `version` field in each `devcontainer-feature.json` and tag the repo accordingly.
- Images publish to `ghcr.io/airnub-labs/dev-base` and `ghcr.io/airnub-labs/dev-web` with tags matching Git refs (e.g., `v1.0.0`). Multi-arch manifests (amd64 + arm64) are produced via `build-images.yml`.
- Templates are versioned via git tags. When cutting a release, update template metadata if new options are introduced and regenerate README badges as needed.
- Document released versions and digests here:

| Artifact | Latest Tag | Notes |
| --- | --- | --- |
| `features/supabase-cli` | `1.0.0` | Installs Supabase CLI + helpers |
| `features/chrome-cdp` | `1.0.0` | Headless Chrome via supervisord |
| `features/agent-tooling-clis` | `1.1.0` | Codex/Claude/Gemini pnpm installers |
| `features/docker-in-docker-plus` | `1.0.0` | Buildx and BuildKit defaults |
| `features/cuda-lite` | `1.0.0` | Conditional CUDA runtime |
| `ghcr.io/airnub-labs/dev-base` | `v1.0.0` | Node 24 + pnpm base |
| `ghcr.io/airnub-labs/dev-web` | `v1.0.0` | Browser-ready extension (published digest pending) |

Update this table as new versions are pushed.

> **Maintainer note:** The prebuilt `dev-web` image has not been published with a digest yet. Keep template references on
> `ghcr.io/airnub-labs/dev-web:latest` until the first digest is promoted, then replace the note above with the pinned
> `@sha256:<digest>` value and update the template documentation matrices.
