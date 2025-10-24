# Workspace Clone Strategy — Implementation Guide

> **Repo context:** This version targets the internal repo `vscode-meta-workspace-internal` and is written to require **minimal edits** when copied to the public template repo (`vscode-meta-workspace`). Inline ⚠️ notes call out the only places you might tweak.

This document explains **how the meta workspace clones project repos** in a single Dev Container / Codespace — what it clones, *why*, and *where* the configuration lives. It’s written so a new contributor can follow it without prior context.

---

## Goals

* **One container, many repos.** Work across multiple projects in one VS Code window, inside one dev container (with a shared Redis and local Supabase stack).
* **No submodules.** Each project is a normal Git clone with its own `origin` remote, so `git push` flows are unchanged.
* **Explicit and predictable.** We declare permissions in a GitHub‑aligned way and clone only the repos we intend.

---

## Conceptual model

1. **Permissions ≠ Clones.**

   * `devcontainer.json → customizations.codespaces.repositories` tells **which repos the Codespace token may access**.
   * A **clone script** actually performs the clones.

2. **Clone candidates come from `devcontainer.json`.**

   * **Explicit entries** listed as `owner/repo` are cloned by default.
   * *(Optional)* **Intersection mode** lets you additionally require that a repo name appear in the VS Code `*.code-workspace` file. Enable it by setting `FILTER_BY_WORKSPACE=1` when you invoke the helper.

3. **Wildcards are for permissions, not a manifest.** You may grant `owner/*` in `devcontainer.json` for convenience. We only expand that wildcard into concrete repos if you opt in (see `ALLOW_WILDCARD`).

---

## Where things live

```
<workspace root>
  .devcontainer/
    devcontainer.json                # declares Codespaces repo permissions
    scripts/
      post-create.sh                 # main post-create entrypoint (already in use)
      post-start.sh                  # optional checks; shared stack bootstrap
      clone-from-devcontainer-repos.sh  # the clone helper (idempotent)
  airnub-labs.code-workspace         # multi-root list of folders you want open
```

> ⚠️ **Public template:** consider renaming `airnub-labs.code-workspace` → `workspace.code-workspace` for a generic template.

---

## How cloning works (step by step)

1. **Post-create runs** inside the container and calls `scripts/clone-from-devcontainer-repos.sh`.
2. The script reads **`devcontainer.json → customizations.codespaces.repositories`** and collects keys:

   * Concrete entries `owner/repo` → always candidates.
   * Wildcards `owner/*` → *ignored by default* (you can enable expansion; see below).
3. If you set **`FILTER_BY_WORKSPACE=1`**, the script reads the `*.code-workspace` file and keeps only repos whose **repo name** appears as a folder path in the workspace file.
4. For each repo to clone:

   * If `/workspaces/<repo_name>/.git` already exists → **fetch/prune** (no merge) and continue.
   * Else clone to `/workspaces/<repo_name>` using the best available auth mode (see next section).

> **Recursion guard:** If `WORKSPACE_ROOT` resolves *inside* this meta workspace folder, the helper logs a warning and falls back to the parent directory so it doesn’t try to create paths like `Projects-Airnub-Labs/Projects-Airnub-Labs`. Likewise, any individual repo whose target would land inside the meta repo is skipped. Keep `WORKSPACE_ROOT` pointing to a parent directory (the default) so clones remain siblings of the workspace repo.

The clone step is **idempotent** and **non-destructive**.

---

## Authentication order (auto mode)

The script picks the first viable method:

1. **`gh` (GitHub CLI)** — if authenticated in the container/Codespace.
2. **SSH** — if an agent is available and GitHub host keys are accepted.
3. **HTTPS+PAT** — if `GH_MULTI_REPO_PAT` is set (token used only during clone; the URL is reset to `https://github.com/owner/repo.git`).
4. **HTTPS (unauthenticated)** — works for public repos only.

You can force a mode via `CLONE_WITH=gh|ssh|https|https-pat`.

---

## Configuration knobs (env vars)

| Variable              | Default                           | What it does                                            |
| --------------------- | --------------------------------- | ------------------------------------------------------- |
| `WORKSPACE_ROOT`      | `/workspaces`                     | Target directory for all clones                         |
| `DEVCONTAINER_FILE`   | `.devcontainer/devcontainer.json` | Where we read the permissions block                     |
| `WORKSPACE_FILE`      | *(auto‑discover)*                 | Path to `*.code-workspace` for folder intersection      |
| `CLONE_WITH`          | `auto`                            | `gh`, `ssh`, `https`, or `https-pat`                    |
| `GH_MULTI_REPO_PAT`   | *(unset)*                         | Token for `https-pat` mode                              |
| `ALLOW_WILDCARD`      | `0`                               | If `1`, expand `owner/*` with `gh repo list`            |
| `FILTER_BY_WORKSPACE` | `0` (clone all declared repos)    | If `1`, intersect candidates with workspace folders     |
| `CLONE_ON_START`      | `false`                           | If `true`, `post-start.sh` will re-run the clone helper |

---

## The permissions block (source of truth)

Add or edit this block in `.devcontainer/devcontainer.json` of the **meta workspace repo**:

```jsonc
{
  "customizations": {
    "codespaces": {
      "repositories": {
        // Explicit repos (recommended)
        "airnub-labs/million-dollar-maps": { "permissions": { "contents": "write", "pull_requests": "write" } },

        // Optional: a convenient superset for permissions (not auto‑cloned unless ALLOW_WILDCARD=1)
        "airnub-labs/*": { "permissions": { "contents": "write", "pull_requests": "write" } }
      }
    }
  }
}
```

> **Note:** permission prompts appear only when creating a **new** Codespace after you commit this file.
>
> ⚠️ **Public template:** replace `airnub-labs/*` with commented examples:
>
> ```jsonc
> // "your-org/your-repo": { "permissions": { "contents": "write", "pull_requests": "write" } }
> ```

---

## Using the workspace file as a human‑readable list

Your `*.code-workspace` defines what folders you want to see in VS Code. When `FILTER_BY_WORKSPACE=1`, it also acts as a **second filter** for cloning:

```json
{
  "folders": [
    { "path": ".devcontainer" },
    { "path": "million-dollar-maps" }
  ],
  "settings": {}
}
```

* Non‑repo entries like `.devcontainer` are ignored by the clone script.
* Add more projects here as you grow the workspace.

> ⚠️ **Public template:** if you rename the file to `workspace.code-workspace`, update any references in scripts.

---

## Script wiring (already set up)

We call the clone helper **from `post-create.sh`** so your existing workflow stays intact. The call looks like this:

```bash
# In .devcontainer/scripts/post-create.sh
if [[ -x "$HERE/clone-from-devcontainer-repos.sh" ]]; then
  ALLOW_WILDCARD=0 \
  bash "$HERE/clone-from-devcontainer-repos.sh" || log "Clone step skipped or failed (non-fatal)"
fi
```

Optionally, `post-start.sh` can **re-run** the clone helper if you set `CLONE_ON_START=true`, or it will log a helpful hint if any configured repos are missing.

---

## Verifying it works

1. Open the workspace in the container; in a terminal run:

   ```bash
   ls /workspaces
   ```

   You should see the repos declared in `devcontainer.json` (or, if filtering, those also present in your workspace file) as directories.
2. Inside one repo, confirm the remote:

   ```bash
   cd /workspaces/million-dollar-maps
   git remote -v
   ```

   It should point to your GitHub repo, and `git push` should work (assuming permissions).

---

## Common scenarios & tips

* **Add a new repo to auto‑clone:**

  1. Add it explicitly under `customizations.codespaces.repositories` (permissions).
  2. Add its folder name to the `*.code-workspace` file (if using intersection mode).
  3. Recreate the Codespace (for new permissions) or re-run the clone helper.

* **Use wildcards for convenience, not for cloning.** Keep `owner/*` as a permission superset; leave `ALLOW_WILDCARD=0` unless you intentionally want to clone the entire org.

* **Private repos not cloning?** Ensure they are explicitly listed in the permissions block (or covered by a wildcard **and** `ALLOW_WILDCARD=1`), and that your chosen auth method can access them.

* **Idempotent by design.** Re-running the helper won’t overwrite local work; it only `fetch --all --prune` on existing clones.

* **Security:** In `https-pat` mode, the token is used only during clone; the script resets the remote to a clean URL.

---

## Manual commands (handy)

```bash
# Re-run clone step (default: clone every repo declared in devcontainer.json)
ALLOW_WILDCARD=0 \
bash .devcontainer/scripts/clone-from-devcontainer-repos.sh

# Optional: intersect with workspace file instead of cloning all declared repos
FILTER_BY_WORKSPACE=1 ALLOW_WILDCARD=0 \
WORKSPACE_FILE="/workspaces/<meta-repo>/airnub-labs.code-workspace" \
bash .devcontainer/scripts/clone-from-devcontainer-repos.sh

# Force a specific auth mode
CLONE_WITH=ssh bash .devcontainer/scripts/clone-from-devcontainer-repos.sh
```

---

## Why we chose this design

* **Aligned with GitHub:** permissions are defined in `devcontainer.json` where Codespaces expects them.
* **Predictable & minimal maintenance:** explicit repos yield deterministic clones; the workspace file is the visible UI list; no submodules or custom mapping files.
* **Portable locally and in Codespaces:** same script and wiring work in both environments.

If you have questions or need to add another project, update the permissions block and (optionally) the workspace file, then re-run the clone helper or create a fresh Codespace.
