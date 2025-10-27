# Devcontainer feature catalog

This workspace uses bespoke devcontainer [features](https://containers.dev/implementors/features/) to compose the inner development environment. Each section below summarises what the feature does, how it is wired into the workspace lifecycle, and which configuration knobs are available.

## GUI tooling

* **Manifest:** [`devcontainers/features/gui-tooling/devcontainer-feature.json`](../devcontainers/features/gui-tooling/devcontainer-feature.json)
* **Lifecycle hooks:** Runs `updateContentCommand` to regenerate `.devcontainer/.env` with the correct Docker Compose profiles via [`bin/update-profiles.sh`](../devcontainers/features/gui-tooling/scripts/update-profiles.sh).
* **Configuration:**
  * `options.providers` – defaults to `webtop` and feeds the GUI profile generator. See the [`providers` option](../devcontainers/features/gui-tooling/devcontainer-feature.json).
  * Container environment variables mirror the previous devcontainer settings (Chrome credentials, GUI ports, locale defaults). See [`containerEnv`](../devcontainers/features/gui-tooling/devcontainer-feature.json) for the exhaustive list.
* **Documentation:** [`devcontainers/features/gui-tooling/README.md`](../devcontainers/features/gui-tooling/README.md)

## Supabase stack bootstrap

* **Manifest:** [`devcontainers/features/supabase-stack/devcontainer-feature.json`](../devcontainers/features/supabase-stack/devcontainer-feature.json)
* **Lifecycle hooks:** Executes the feature [`postStartCommand`](../devcontainers/features/supabase-stack/devcontainer-feature.json) to wait for Docker, start the Supabase stack, and sync `.env.local` values through [`bin/bootstrap-supabase.sh`](../devcontainers/features/supabase-stack/scripts/bootstrap-supabase.sh).
* **Configuration:**
  * Environment overrides for `SUPABASE_INCLUDE`, `SUPABASE_PROJECT_DIR`, `SUPABASE_CONFIG_PATH`, `SUPABASE_START_ARGS`, and `SUPABASE_START_EXCLUDES` are propagated from host to container via [`containerEnv`](../devcontainers/features/supabase-stack/devcontainer-feature.json).
  * The Supabase task palette entry now delegates to [`bin/supabase-up.sh`](../devcontainers/features/supabase-stack/scripts/supabase-up.sh), which honours the same include/exclude variables.
* **Documentation:** [`devcontainers/features/supabase-stack/README.md`](../devcontainers/features/supabase-stack/README.md)

## Agent tooling CLIs

* **Manifest:** [`devcontainers/features/agent-tooling-clis/devcontainer-feature.json`](../devcontainers/features/agent-tooling-clis/devcontainer-feature.json)
* **Lifecycle hooks:** Installs the selected agent CLIs during the container build and falls back to an `npx` shim when a package cannot be installed (for example, when `npm` is unavailable).
* **Configuration:**
  * `installCodex`, `installClaude`, and `installGemini` toggle the OpenAI Codex, Anthropic Claude Code, and Google Gemini CLIs respectively.
  * The feature intentionally avoids editor-specific MCP wiring; template post-create hooks (or committed client settings) take care of registering MCP servers with the installed CLIs.
* **Documentation:** [`devcontainers/features/agent-tooling-clis/README.md`](../devcontainers/features/agent-tooling-clis/README.md)

## Docker-in-Docker helpers

* **Manifest:** [`devcontainers/features/docker-in-docker-helpers/devcontainer-feature.json`](../devcontainers/features/docker-in-docker-helpers/devcontainer-feature.json)
* **Lifecycle hooks:** The feature [`postStartCommand`](../devcontainers/features/docker-in-docker-helpers/devcontainer-feature.json) runs [`bin/post-start.sh`](../devcontainers/features/docker-in-docker-helpers/scripts/post-start.sh) to authenticate with Amazon ECR Public, ensure the inner Redis container is up, and provide clone hints for multi-repo workspaces.
* **Configuration:**
  * Inherits Docker wait timings (`DOCKER_WAIT_ATTEMPTS`, `DOCKER_WAIT_SLEEP_SECS`) from the container environment if set, matching the previous script behaviour.
  * Continues to respect `CLONE_ON_START`, `WORKSPACE_STACK_NAME`, `WORKSPACE_CONTAINER_ROOT`, and other workspace-level variables consumed by the helper script.
* **Documentation:** [`devcontainers/features/docker-in-docker-helpers/README.md`](../devcontainers/features/docker-in-docker-helpers/README.md)
