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

   * `.devcontainer/devcontainer.json → customizations.codespaces.repositories` tells **which repos the Codespace token may access**.
   * `workspace.blueprint.json` records **which repos should actually be cloned**.

2. **Blueprint manifests drive the clone list.** Each workspace variant (`workspaces/webtop`, `workspaces/novnc`, …) owns a blueprint that lists `{ url, path, ref? }` entries. Paths should live under `/apps` so the clones stay ignored by Git.

3. **Permissions still gate access.** Grant each blueprint repo at least `contents: read`. Wildcards in the permissions block are fine for convenience but do **not** trigger automatic cloning on their own.

---

## Where things live

```text
<workspace root>
  .devcontainer/
    devcontainer.json                # bridge that points at workspaces/webtop/.devcontainer
  workspaces/
    webtop/
      .devcontainer/
        devcontainer.json            # concrete config used by the default variant
      postCreate.sh                  # post-create entrypoint that applies the blueprint
      postStart.sh                   # optional startup hook
      workspace.blueprint.json       # manifest of repos cloned into /apps
    novnc/
      …
  airnub-labs.code-workspace         # multi-root list of folders you want open
```

> ⚠️ **Public template:** consider renaming `airnub-labs.code-workspace` → `workspace.code-workspace` for a generic template.

---

## How cloning works (step by step)

1. **`postCreate.sh` runs** inside the container after VS Code provisions features.
2. The script reads **`workspace.blueprint.json`** and collects each `{ url, path, ref? }` entry.
3. For every repo:

   * If the target path already contains a Git repo → log `[skip] exists: <path>` and continue.
   * Else clone to the requested location and, if `ref` is set, check it out.

   After the loop, helpers such as `airnub use` can inspect `/apps` to locate projects. Re-running the script is safe—it only clones what’s missing.

The clone step is **idempotent** and **non-destructive**. Keep blueprint paths under `/apps` (which is git-ignored) so clones never pollute commits.

---

## Authentication expectations

Clones rely on the standard Git credential chain inside the container:

1. **GitHub CLI (`gh auth status`)** — recommended; Codespaces pre-authenticates this.
2. **SSH agent** — works if you’ve forwarded keys or configured Codespaces `forwardPorts` secrets.
3. **HTTPS** — falls back to any cached credentials or prompts (public repos work without auth).

If you need to script non-interactive HTTPS clones, set `GH_TOKEN`/`GITHUB_TOKEN` or configure the Git credential helper before rerunning `postCreate.sh`.

---

## Configuration knobs

Most behaviour is declarative now:

| Setting | Where | Purpose |
| --- | --- | --- |
| `customizations.codespaces.repositories` | `.devcontainer/devcontainer.json` | Grants the Codespace token permission to access repos listed in blueprints. |
| `workspace.blueprint.json` | `workspaces/<variant>/` | Lists repos to clone (URL, `/apps/...` path, optional `ref`). |
| `postStart.sh` | `workspaces/<variant>/` | Optional follow-up tasks (e.g., starting Supabase) once the container is running. |

Environment overrides from the legacy clone helper are no longer required.

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

Your `*.code-workspace` defines what folders you want to see in VS Code. It no longer filters clones, but we still reference it for developer hints:

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

`workspaces/<variant>/postCreate.sh` invokes an inline Node script that parses the blueprint and runs `git clone` for each entry. Because it lives in the repo, you can tweak it per variant if you need additional bootstrap steps (for example seeding data after clones finish).

`postStart.sh` remains available for optional tasks (starting Supabase, sanity checks, etc.) but no longer needs to manage cloning.

---

## Verifying it works

1. Open the workspace in the container; in a terminal run:

   ```bash
   ls /apps
   ```

   You should see the repos listed in your blueprint cloned into `/apps` (if none are listed, the directory is empty).
2. Inside one repo, confirm the remote:

   ```bash
   cd /apps/million-dollar-maps
   git remote -v
   ```

   It should point to your GitHub repo, and `git push` should work (assuming permissions).

---

## Common scenarios & tips

* **Add a new repo to auto‑clone:**

  1. Add it explicitly under `customizations.codespaces.repositories` (permissions).
  2. Recreate the Codespace (for new permissions) or re-run the clone helper.

* **Use wildcards for convenience, not for cloning.** Keep `owner/*` as a permission superset; leave `ALLOW_WILDCARD=0` unless you intentionally want to clone the entire org.

* **Private repos not cloning?** Ensure they are explicitly listed in the permissions block and that your credential helper can access them.

* **Idempotent by design.** Re-running the helper won’t overwrite local work; it skips directories that already contain a Git repo.

* **Security:** Credentials never hit disk; `git clone` relies on your authenticated helper (GitHub CLI, SSH agent, or HTTPS).

---

## Manual commands (handy)

```bash
# Re-run clone step for the default variant
bash workspaces/webtop/postCreate.sh

# Re-run clone step for the noVNC variant
bash workspaces/novnc/postCreate.sh
```

---

## Why we chose this design

* **Aligned with GitHub:** permissions are defined in `devcontainer.json` where Codespaces expects them.
* **Predictable & minimal maintenance:** explicit repos yield deterministic clones; the workspace file is the visible UI list; no submodules or custom mapping files.
* **Portable locally and in Codespaces:** same script and wiring work in both environments.

If you have questions or need to add another project, update the permissions block and the relevant blueprint, then rerun the variant’s `postCreate.sh` or create a fresh Codespace.
