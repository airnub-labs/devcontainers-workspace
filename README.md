# vscode-meta-workspace-internal

> One dev container, many projects — with a shared Redis and **one** local Supabase stack. Works locally and in **GitHub Codespaces**.

This repo gives you a ready-to-go workspace for Airnub Labs projects. Open a single VS Code window and the Dev Container boots a workspace that mounts sibling repos and exposes a single, shared Supabase + Redis runtime.

Why a shared stack? Running one Supabase and Redis instance avoids the common local developer problems of "too many ports", duplicate local databases, and the CPU/memory cost of multiple full stacks. It makes switching between projects fast, reduces container churn, and keeps local resource usage predictable.

---

## What you get

* **Multi-root workspace:** `airnub-labs.code-workspace` opens all of your project folders side-by-side.
* **Shared runtime:** the Dev Container maps the parent directory to `/workspaces`, provides Docker-in-Docker, Node 24 with pnpm, Python 3.12, and ships with Redis plus a Supabase local stack configured in [`supabase/config.toml`](./supabase/config.toml).
* **Helper scripts:** `workspaces/<variant>/postCreate.sh` reads the matching `workspace.blueprint.json` manifest to clone sibling repos into `/apps`, while `supabase/scripts/` keeps local Supabase credentials in sync across repos.

---

## Quick start

### Fast iPad edits via VS Code for Web

On an iPad (or any browser-only device) you can jump straight into this workspace without installing anything locally:

1. Open [vscode.dev/github/airnub-labs/vscode-meta-workspace-internal](https://vscode.dev/github/airnub-labs/vscode-meta-workspace-internal) for a lightweight, browser-based VS Code instance that loads this repo instantly. Press `.` while viewing the repo on GitHub to land in [github.dev](https://github.dev/airnub-labs/vscode-meta-workspace-internal) if you prefer the GitHub-flavoured editor.
2. When you need more power, use the **Remote** menu inside vscode.dev or github.dev to connect to an existing Codespace or create a new one for this repository.
3. Alternatively, browse to the repository on GitHub and choose **Code → Create codespace on main** to launch a full Codespace session directly.

### AI coding extensions

GitHub Codespaces automatically adds three AI assistants to this workspace. When you run the Dev Container locally you can install them from the Marketplace using the commands below, and VS Code will remember your session across restarts of the same container.

* **GitHub Copilot Chat** (`GitHub.copilot-chat`)
  * Open the Command Palette and run `>GitHub: Sign in` (or use the Copilot Chat view’s sign-in button).
  * Authorize with your GitHub account in the browser that opens. In Codespaces the authentication popup appears in the built-in browser automatically.
  * After approving the request, the chat panel and inline completions activate immediately.
* **ChatGPT** (`openai.chatgpt`)
  * Run `>ChatGPT: Sign In` and follow the prompts in the external browser.
  * When you are in a local VS Code window, complete the OAuth flow in the browser as usual.
  * When you are in a Codespace, copy the final redirect URL from the external browser and paste it into a Codespaces preview tab (Ports panel → **Open in Browser**). That forces the callback through the Codespaces tunnel so the extension finishes signing you in.
* **Claude Code** (`anthropic.claude-code`)
  * Launch `>Claude: Sign In` from the Command Palette or click the sign-in link inside the Claude sidebar.
  * Approve the Anthropic authorization request in the browser. The Codespaces webview handles the callback automatically, so no extra steps are required after granting access.

Once you finish the respective sign-ins you can start using chat panels or inline suggestions without re-authenticating unless you destroy the workspace.

### Using this workspace in your own GitHub org

When you want to bring this workspace into your own GitHub org, choose one of these paths:

* **Create a new repo from this template** – keeps your copy private and lets you customize without affecting the original. In GitHub, choose **Use this template → Create a new repository** and pick your organization/visibility.
* **Fork this repo** – keeps an upstream link for easy updates, but the fork will be public to match this repository’s visibility. Only go this route if public visibility is acceptable.

The first build of the Dev Container or Codespace takes a few minutes while the image assembles. After that initial build, starting/stopping the container (locally or in Codespaces) is quick, and the environment behaves the same in both places.

### Option A — Local VS Code + Dev Containers

1. Open this repository in VS Code and choose **Reopen in Container**. The root `.devcontainer/devcontainer.json` bridges to the default `workspaces/webtop` variant so Codespaces and the Dev Containers extension share the same configuration.
2. In the Dev Container terminal, list the mounted repos with `ls /workspaces` (the repo itself) or `ls /apps` (cloned via `workspace.blueprint.json`).
3. Start the shared services once per session: `supabase start -o env` (Studio: [http://localhost:54323](http://localhost:54323), API: [http://localhost:54321](http://localhost:54321)). This single stack serves all projects in `/workspaces` and `/apps` so you don't need a separate Supabase instance per repo.
4. Work in a project folder (for example `cd /apps/million-dollar-maps`) and run that project’s migrations against the shared stack.

### Option B — GitHub Codespaces

1. Create a Codespace from this repo.
2. (Optional) Update `.devcontainer/devcontainer.json → customizations.codespaces.repositories` so the Codespace token can clone other private repos.
3. Securely add any required secrets via the Codespaces command palette: press <kbd>Shift</kbd>+<kbd>Command</kbd>+<kbd>P</kbd> (macOS) or <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> (Windows/Linux), type `>Codespaces: Manage User Secrets`, and follow the prompts to set key/value pairs that your workspace can access.
4. After the container boots, inspect `/apps` to confirm that `postCreate.sh` cloned repos listed in the blueprint. Use the same Supabase workflow as local.

Need a refresher on the helper scripts or the clone automation? See the docs linked below.

---

## Shared Supabase workflow (at a glance)

* Services run with the project ref defined in [`supabase/config.toml`](./supabase/config.toml) — by default `airnub-labs`.
* Prefer the repository's CLI wrapper for day-to-day tasks (available globally as `airnub` once the Dev Container setup completes):

  ```bash
  airnub use                                # reuse the last project (or default supabase/)
  airnub use ./million-dollar-maps                  # sync env vars + push migrations + show status
  airnub project current                            # see which project was activated last
  airnub project setup --project-dir ./million-dollar-maps  # seed .env.local then sync Supabase credentials
  airnub db env diff                                     # compare Supabase CLI env output with supabase/.env.local
  airnub db env sync --ensure-start                      # refresh supabase/.env.local (start services if needed)
  airnub db env clean                                    # remove the shared supabase/.env.local file
  airnub project env diff --project-dir ./million-dollar-maps   # compare project env with shared Supabase vars
  airnub project env sync --project-dir ./million-dollar-maps   # merge shared Supabase vars into the project env file
  airnub project env clean --project-dir ./million-dollar-maps  # remove the project's generated env file
  airnub db apply --project-dir ./million-dollar-maps
  airnub db reset --project-dir ./million-dollar-maps
  airnub db status --project-dir ./million-dollar-maps
  airnub project clean                                      # forget the remembered project selection
  ```

  When the devcontainer clone helper runs for the first time it seeds `./.airnub-current-project` with the first cloned repo
  (and falls back to `./supabase` if nothing was cloned yet) so new contributors land on a sensible default for the shared stack.
  Run `airnub use` without arguments any time to reuse that remembered selection (or the default `supabase/`).

* Run migrations with the Supabase CLI from the workspace root, pointing at the project with `--workdir`:

```bash
supabase db push --workdir ./<project-name> --local
```

* Legacy tooling that still invokes `supabase/scripts/use-shared-supabase.sh` now delegates to the `airnub` CLI, so existing scripts keep working while `airnub db ...` remains the source of truth (you can still run `./airnub` directly if you prefer explicit paths).

---

## Learn more

* **[Workspace architecture](./docs/workspace-architecture.md):** how the Dev Container is wired, what services run, and how the multi-root workspace is organized.
* **[Shared Supabase operations](./docs/shared-supabase.md):** start/stop commands, helper script usage, and env-var management.
* **[Workspace clone strategy](./docs/clone-strategy.md):** how repo permissions translate into automatic cloning in Dev Containers and Codespaces.
* **[Dev Container spec alignment](./docs/SPEC-ALIGNMENT.md):** how features, templates, and stacks align with the Dev Containers spec and GHCR distribution.
* **[Feature & template catalog](./docs/CATALOG.md):** overview of the available tooling features and workspace templates.

---

**TL;DR:** Open the workspace, run `supabase start -o env`, and develop any Airnub Labs project against the shared stack without juggling multiple containers.
