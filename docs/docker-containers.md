# Docker container architecture

This repository relies on two layers of containers:

1. **Outer Dev Container** – defined by VS Code in [`.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json) and [`containers/compose/base.yaml`](../containers/compose/base.yaml). It installs the tooling used across every project.
2. **Inner Docker daemon** – provided by the `docker-in-docker` feature so the Dev Container can launch services such as the shared Supabase stack.

Understanding the responsibilities of each layer makes it easier to tune performance, persist the right data, and troubleshoot issues.

---

## Outer Dev Container

The Dev Container is launched via Docker Compose with the project name `airnub-labs` (or the value of `WORKSPACE_STACK_NAME`). Key settings (see the profile definitions in [`.devcontainer/profiles/`](../.devcontainer/profiles)):

- **Workspace mount** – The repository root is mounted at `${WORKSPACE_CONTAINER_ROOT:-/airnub-labs}`. A `:cached` flag is present for backwards compatibility but is optional on modern Docker (virtiofs handles synchronization efficiently).
- **Named volume for DinD cache** – `dind-data:/var/lib/docker` keeps the inner Docker images and build cache between sessions. This speeds up Supabase restarts and other DinD workloads. When it grows too large, run `docker system df`, `docker image prune -f`, `docker builder prune -af`, and `docker volume prune -f` _inside_ the Dev Container to recover space.
- **Additional feature volumes** – Node’s pnpm store is persisted in `global-pnpm-store`. See the `mounts` section in [`devcontainer.json`](../.devcontainer/devcontainer.json) for details.

You can customise container-wide behaviour by setting environment variables before the Dev Container starts:

| Variable | Purpose |
| --- | --- |
| `WORKSPACE_CONTAINER_ROOT` | Changes the mount point where the repo appears inside the container. |
| `WORKSPACE_STACK_NAME` | Updates the Compose project name used by `containers/compose/base.yaml` and downstream scripts. |
| `DEVCONTAINER_PROJECT_NAME` | Overrides the project label written to logs. |

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

[`post-start.sh`](../.devcontainer/scripts/post-start.sh) creates the required directories just before running `supabase start`:

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
2. **Change persistence strategy** – Remove `dind-data` from [`containers/compose/base.yaml`](../containers/compose/base.yaml) if you prefer the inner Docker cache to reset on each rebuild, or mount a different named volume if you want project-specific caches.
3. **Tune resources** – Update `containers/compose/base.yaml` to set `shm_size`, CPU limits, or memory reservations when working with resource-intensive tooling.
4. **Disable DinD** – If your environment forbids privileged containers (e.g., certain Codespaces policies), remove `privileged: true` and the DinD feature from [`devcontainer.json`](../.devcontainer/devcontainer.json). In that case configure Supabase to use a remote Docker host or a sidecar service instead.

For more information on how the shared Supabase stack operates once it is running, see [`docs/shared-supabase.md`](./shared-supabase.md).
