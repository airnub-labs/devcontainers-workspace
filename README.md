# vscode-meta-workspace-internal

> One dev container, many projects — with a shared Redis and **one** local Supabase stack. Works locally and in **GitHub Codespaces**.

> **Public template note:** This README is written so it can be copied to the public template repo (`vscode-meta-workspace`) with minimal edits. See the inline ⚠️ notes.

This repository is a **meta workspace** for developing multiple projects side‑by‑side in a **single** Dev Container. It pairs a multi‑root VS Code workspace with a shared runtime (Redis + Supabase local stack), so you don’t have to juggle several containers or keep track of different Supabase ports per project. Instead, you focus on **one active project at a time** and run its migrations against the shared local stack.

* Multi‑root workspaces let one VS Code window contain multiple folders/repos.
* The Dev Container mounts the **parent** folder into the container (→ `/workspaces`), so all sibling projects are visible.
* One shared Supabase + Redis is available for whichever project is active.

---

## 📚 Clone Strategy & Implementation

New to this workspace? Read the detailed guide:

* **[Workspace Clone Strategy — Implementation Guide](./docs/clone-strategy.md)**

That doc explains how repository permissions are declared, how the clone helper works, and how it stays aligned with Codespaces. It also covers intersection with the multi‑root workspace file and optional wildcard behavior.

> ⚠️ **Public template:** if you move this doc under `docs/`, update this link to `./docs/clone-strategy.md`.

---

## Why this exists

Running a full Supabase stack per project (each with different ports) was cumbersome. This workspace provides:

* **One** Dev Container with Docker‑in‑Docker, Node (with pnpm), and Python tooling, plus a Redis sidecar.
* **One** local Supabase stack (via the Supabase CLI) used by whichever project you’re actively developing; you simply run that project’s migrations (and only that project’s) when switching.

> Supabase’s local stack includes Postgres, Auth, Storage, and Studio. Common local defaults: **API 54321**, **DB 54322**, **Studio 54323**, **Inbucket 54324**, **Storage 54326** (configurable in `supabase/config.toml`).

---

## How this workspace differs from per‑project `.devcontainer/`

**This workspace repo** (meta workspace):

* Lives at the **parent** level (e.g. `Projects-Airnub-Labs/`).
* Contains a `.devcontainer/` that mounts the **parent** folder to `/workspaces`, exposing all repos in one container.
* Includes `airnub-labs.code-workspace` (multi‑root) so you can open multiple repos in one VS Code window.
* Runs **one** shared Supabase stack + Redis for **any** project in the workspace.

**Each project repo** (e.g. `million-dollar-maps`) still has its **own** `.devcontainer/`:

* So you can open that repo directly in **GitHub Codespaces** (or locally) with a predictable, repo‑scoped environment.

**When to use which**

* Day‑to‑day, single‑repo work in Codespaces → open the project repo (uses its own `.devcontainer/`).
* Cross‑repo work locally or in a “meta” Codespace → open this **workspace repo** (clones/opens multiple repos together and shares one runtime). You can grant extra repo permissions in `devcontainer.json` so the Codespace can read/write other repos.

> ⚠️ **Public template:** in `.devcontainer/devcontainer.json`, ship **placeholders** for `customizations.codespaces.repositories` instead of org‑wide wildcards.

---

## What’s inside

* **`.devcontainer/`**

  * `devcontainer.json` uses Dev Container **Features** (Docker‑in‑Docker, Node, pnpm, Python) to standardize tooling.
  * `docker-compose.yml` mounts the **parent** directory at `/workspaces` so all sibling repos appear inside the container.
  * `scripts/` includes post‑create/start hooks and the clone helper.
* **`airnub-labs.code-workspace`**

  * Lists your projects (e.g., `million-dollar-maps`, etc.) as folders in a single window.

> ⚠️ **Public template:** consider renaming the workspace file to `workspace.code-workspace`.

---

## Local usage (VS Code Dev Containers)

1. **Open the workspace**: open `airnub-labs.code-workspace` → **Reopen in Container**.
2. **Verify mount**: in the container terminal, `ls /workspaces` should show all project folders (we bind‑mount the parent to `/workspaces`).
3. **Start Supabase (once):**

```bash
# inside the container
supabase start
# Studio: http://localhost:54323  | API: http://localhost:54321
```

4. **Work on a project**: open `/workspaces/million-dollar-maps` in the Explorer.
5. **Run that project’s migrations only** (example):

```bash
cd /workspaces/million-dollar-maps
# choose the command you use in this repo
supabase db push          # or: supabase db reset --local
```

> This applies *that repo’s* schema to the shared local stack. Switch projects by applying **their** migrations next.

**Tip:** VS Code follows **one window = one container**. If you need a different container, open another window.

---

## Codespaces usage

You have two options:

### A) Open a **project** repo in Codespaces

* Click **Code → Create codespace** in that repo. It uses the repo’s own `.devcontainer/`.

### B) Open the **workspace repo** in Codespaces (multi‑repo session)

* Create a Codespace from this workspace repo.
* (Optional) Configure `customizations.codespaces.repositories` in its `devcontainer.json` to grant the Codespace token **read/write** to other repos (so you can clone/push to them without extra auth). You’ll approve these scopes when the Codespace is created.
* After boot, clone sibling repos into `/workspaces/<repo>` and proceed exactly like local.

> ⚠️ **Public template:** include commented examples in `devcontainer.json` for the `repositories` block so users can fill their own.

---

## Common tasks

**Add another project to the workspace**

1. Add its folder path to `airnub-labs.code-workspace` → save.
2. (If using the meta Codespace) clone it into `/workspaces/<new-repo>`.

**Switch active project**

1. Stop any running app servers from the previous project.
2. `cd /workspaces/<other-project>` → apply migrations for that project only.

**Connect an app to local Supabase**

* Use `SUPABASE_URL=http://localhost:54321` and your local anon/service keys as per the CLI output/Studio.

---

## Gotchas

* **One runtime at a time:** Don’t spin up multiple Supabase stacks on different ports; this workspace assumes one shared stack.
* **Port expectations:** If you customize ports in `supabase/config.toml`, update any app env files accordingly.
* **Rebuild vs recreate:** Changes to `devcontainer.json` usually require a **Rebuild**; some changes (like Codespaces repo permissions) only apply to **new** Codespaces after commit.
* **Keep clones outside the meta repo folder:** The clone helper skips any target that would live inside this repo (to prevent recursive `Projects-Airnub-Labs/Projects-Airnub-Labs`-style paths). Let the helper place sibling repos next to the meta workspace folder or override `WORKSPACE_ROOT` with another parent directory.

---

## Quick reference commands

```bash
# In container: list projects
ls /workspaces

# Start/stop Supabase
supabase start
supabase stop

# Apply a project’s DB changes
cd /workspaces/<project>
supabase db push
# or
supabase db reset --local
```

---

**TL;DR:** One container, one Redis, one Supabase stack. Work across many repos without port chaos—just run *one project’s* migrations at a time.
