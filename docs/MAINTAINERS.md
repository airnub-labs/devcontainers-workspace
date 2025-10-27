# Maintainer Notes

- Version bumps flow through `VERSIONING.md`. Update the matrix when publishing a new feature or image tag.
- Use the provided GitHub Actions workflows to cut releases:
  - `publish-features.yml` pushes updated OCI artifacts for each `features/*` directory.
  - `build-images.yml` builds multi-arch images for `images/dev-base` and `images/dev-web` and pushes them to GHCR.
  - `test-features.yml` and `test-templates.yml` run schema validation and container smoke tests prior to release.
- After tagging, run `devcontainer templates publish` (or rely on CI automation) to publish template metadata.
- Keep documentation in `docs/` synchronized with repo changes, especially when adding new templates or template options.
