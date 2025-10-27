# Docker-in-Docker helpers feature

## Purpose
This feature layers helper scripts on top of the upstream `docker-in-docker` feature. The post-start helper waits for the inner Docker daemon, authenticates to Amazon ECR Public to avoid pull rate limits, ensures a Redis container is running inside the nested daemon, and prepares multi-repo workspace metadata/logging under `/var/log/devcontainer`.

## Inputs & options
The feature does not expose custom options. Behaviour can be tuned through environment variables that the helper respects when present:

- `DOCKER_WAIT_ATTEMPTS` / `DOCKER_WAIT_SLEEP_SECS` – control how long the helper waits for the Docker daemon to report healthy.
- `WORKSPACE_STACK_NAME`, `DEVCONTAINER_PROJECT_NAME`, `WORKSPACE_CONTAINER_ROOT` – shape log locations and workspace naming defaults.
- Standard workspace flags such as `CLONE_ON_START` and credentials that may be referenced by the helper logic.

## Lifecycle hooks
`postStartCommand` runs [`bin/post-start.sh`](./scripts/post-start.sh). The script determines the repo root, initialises log files, waits for Docker, optionally installs `jq`, authenticates to ECR Public, makes sure the `redis` container exists and is started, and inspects `.code-workspace` files to surface clone hints for multi-repo workspaces.

## Compatibility
Designed to compose with `ghcr.io/devcontainers/features/docker-in-docker`. It requires the Docker CLI to be available inside the container and tolerates hosts without `sudo` or `jq` by skipping those code paths. The helper safely no-ops when Docker is unavailable or Redis conflicts with existing containers, making it suitable for Codespaces and local CLI usage alike.
