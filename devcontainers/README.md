# Dev Containers catalogue (in progress)

This directory will house the spec-compliant **features**, **templates**, and **stacks** that back the meta workspace. The structure mirrors the official [Dev Containers distribution model](https://containers.dev/implementors/spec/) so each artifact can be validated and published to GHCR.

```
features/
templates/
stacks/
```

Each subfolder will contain:

- A metadata file (`devcontainer-feature.json`, `template.json`, or `stack.json`).
- Implementation assets such as install scripts or Docker Compose overrides.
- A README documenting options, prerequisites, and sample usage.

During development we reference these packages locally via `file:` URIs. Release workflows convert them to fully-qualified registry references (`ghcr.io/airnub-labs/devcontainers/<id>@<version>`) so external repos and Codespaces can consume the exact same configuration.

For more detail on the roadmap and planned artefacts, see [../docs/devcontainer-spec-alignment.md](../docs/devcontainer-spec-alignment.md).
