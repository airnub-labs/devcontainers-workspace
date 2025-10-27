# Path to a 100/100 Devcontainers Alignment Score

The automated rubric currently reports an **81/100** alignment score for `airnub-labs/vscode-meta-workspace-internal@refactor-2`.
This section itemizes the concrete gaps that must be closed—plus the minor scoring heuristics that need adjustment—to hit a perfect score.【F:Devcontainers-Alignment-Report.md†L5-L31】

## Confirmed Gaps

### 1. Multi-repo strategy (−5 points)
None of the template payloads pre-clone companion repositories via `customizations.codespaces.repositories`, and there is no `workspace.repos.yaml` fallback manifest in the repository.【F:templates/web/.template/.devcontainer/devcontainer.json†L1-L28】【9c55d7†L1-L2】

**What to add**
- Extend each template’s `.template/.devcontainer/devcontainer.json` with a `customizations.codespaces.repositories` block so Codespaces pre-populates required repos.
- Add a `workspace.repos.yaml` (either globally under `.devcontainer/` or per-template) plus a lightweight helper script or feature that hydrates the manifest when the dev container starts.

### 2. Template version metadata (−1 point)
All template definitions omit the required `"version"` property, so they cannot be semantically versioned when published.【F:templates/web/devcontainer-template.json†L1-L25】

**What to add**
- Add a `"version": "1.0.0"` (or similar semantic version) field near the top of every `devcontainer-template.json`.
- Update release documentation to describe how template and feature versions are incremented together.

## Heuristic False Negatives to Resolve (affects the scorecard, not the underlying spec work)

The remaining 13 points are blocked by conservative checks in `.score/scripts/checks.sh`. The repo already meets the spec expectations, but the script needs small adjustments so the score reflects reality.

### A. Feature separation-of-concerns flag
The Supabase CLI feature only installs helper wrappers (`sbx-start`, `sbx-stop`, `sbx-status`), yet the script flags any mention of `supabase start` as if the feature were launching services during install.【F:features/supabase-cli/install.sh†L109-L156】 Update the heuristic to ignore static helper scripts or move these helpers into documentation if preferred.

### B. Sidecar browser detection
The classroom template already declares a `webtop` sidecar with labeled ports in YAML, but the checker looks for a JSON string literal (`"webtop"`) and therefore misses it.【F:templates/classroom-studio-webtop/.template/.devcontainer/compose.yaml†L1-L21】【F:templates/classroom-studio-webtop/.template/.devcontainer/devcontainer.json†L1-L25】 Teach the script to parse YAML (e.g., via `yq`) or fall back to a case-insensitive search for the bare word `webtop`.

### C. Feature version detection
Every feature’s `devcontainer-feature.json` already includes a semantic `version` field, yet the checker uses a basic `grep` pattern with `\s`, which BusyBox `grep` treats literally. Switching to `grep -E` (or reusing `rg`) restores the expected detection so the last two points are awarded automatically.【F:features/chrome-cdp/devcontainer-feature.json†L1-L16】【F:features/cuda-lite/devcontainer-feature.json†L1-L11】【F:features/docker-in-docker-plus/devcontainer-feature.json†L1-L14】【F:features/mcp-clis/devcontainer-feature.json†L1-L16】【F:features/supabase-cli/devcontainer-feature.json†L1-L26】

## Checklist to Reach 100/100

1. Add Codespaces repository pre-clone blocks and a workspace manifest helper (5 points).
2. Insert `version` fields into every template definition (1 point).
3. Patch the scorecard heuristics for service-start detection, sidecar YAML parsing, and feature version parsing so the automation stops reporting false negatives (13 points).

Completing these items will raise the next scorecard run to the full 100/100 while keeping the repo aligned with the Dev Container Features & Templates distribution guidelines.
