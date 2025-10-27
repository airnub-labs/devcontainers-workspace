# Docker container architecture

This repository relies on two layers of containers:

1. **Outer Dev Container** – defined by the workspace variant in [`workspaces/webtop/.devcontainer/devcontainer.json`](../workspaces/webtop/.devcontainer/devcontainer.json) (the root `.devcontainer/devcontainer.json` simply bridges to it). It installs the tooling used across every project.
2. **Inner Docker daemon** – provided by the `docker-in-docker` feature so the Dev Container can launch services such as the shared Supabase stack.

Understanding the responsibilities of each layer makes it easier to tune performance, persist the right data, and troubleshoot issues.

---

## Outer Dev Container

The Dev Container is launched via Docker Compose with the project name `airnub-labs`. Key settings from [`compose.yaml`](../workspaces/webtop/.devcontainer/compose.yaml):

- **Workspace mount** – The repository root is mounted at `/workspaces` for the dev container and `/workspace` for GUI sidecars. Apps cloned from blueprints land in `/apps` (a bind mount inside the repo, ignored by Git).
- **Shared memory** – `shm_size: "2gb"` avoids Chrome crashes in the GUI sidecars.
- **Redis sidecar** – Included in every variant so the shared runtime is always available.

---

## Inner Docker daemon

The inner Docker daemon runs inside the Dev Container so tools like the Supabase CLI can use Docker Compose without accessing the host Docker socket. The daemon inherits two important persistence points:

1. **Image and layer cache** – Stored in the `dind-data` named volume mounted at `/var/lib/docker`. Delete this volume if you need to reclaim space or want a clean slate for cached images.
2. **Project-scoped Supabase data** – Bind-mounted directories under `supabase/docker/volumes/` keep database and storage state alongside your codebase.

### Supabase compose override

The Supabase CLI automatically loads [`supabase/docker/docker-compose.override.yml`](../supabase/docker/docker-compose.override.yml) alongside its generated Compose file. This repository uses the override to bind-mount the two services that store persistent data:

```yaml
services:
  db:
    volumes:
      - ./volumes/db:/var/lib/postgresql/data:delegated
  storage:
    volumes:
      - ./volumes/minio:/data:delegated
```

The `:delegated` flag prefers container writes over host syncs, which improves database performance when running under virtiofs. Additional Supabase services are stateless, but you can extend this override with more bind mounts if you introduce services that keep local state (for example, vector databases or log folders).

All folders under `supabase/docker/volumes/` are ignored by Git so you can safely keep large datasets or reset them between projects without affecting commits.

### Directory bootstrap

[`postStart.sh`](../workspaces/webtop/postStart.sh) creates any required directories just before running `supabase start` (if you enable it):

```bash
mkdir -p "$SUPABASE_PROJECT_DIR/docker/volumes/db" \
         "$SUPABASE_PROJECT_DIR/docker/volumes/minio"
```

If you add more bind mounts to the override file, update the script to create the matching directories so Supabase can start cleanly after a fresh clone.

### Stable Compose project name

Supabase’s generated Compose files derive their project name from the directory path, which can change between local checkouts and Codespaces. To prevent churn, the post-start script exports `COMPOSE_PROJECT_NAME="${WORKSPACE_STACK_NAME}-supabase"` whenever it runs `supabase status` or `supabase start`. This ensures the inner Docker networks and volumes keep deterministic names even if the workspace path changes.

You can customise the prefix by setting `WORKSPACE_STACK_NAME` before the Dev Container initializes.

---

## Customising the setup

1. **Adjust Supabase services** – Edit [`supabase/docker/docker-compose.override.yml`](../supabase/docker/docker-compose.override.yml) to add, remove, or retarget bind mounts. Remember to create the new directories in `post-start.sh`.
2. **Change persistence strategy** – Adjust the `dind-data` volume in [`compose.yaml`](../workspaces/webtop/.devcontainer/compose.yaml) if you prefer the inner Docker cache to reset on each rebuild, or mount a different named volume for project-specific caches.
3. **Tune resources** – Update the variant’s `compose.yaml` to set `shm_size`, CPU limits, or memory reservations when working with resource-intensive tooling.
4. **Disable DinD** – If your environment forbids privileged containers (e.g., certain Codespaces policies), remove the Docker-in-Docker feature from [`devcontainer.json`](../workspaces/webtop/.devcontainer/devcontainer.json). In that case configure Supabase to use a remote Docker host or a sidecar service instead.

For more information on how the shared Supabase stack operates once it is running, see [`docs/shared-supabase.md`](./shared-supabase.md).
