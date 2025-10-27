# airnub Dev Container feature bundles

This directory follows the [Dev Container Feature distribution spec](https://containers.dev/implementors/features-distribution/)
so each GUI/runtime building block can be versioned and published independently.

Every feature drops a compose overlay into `/usr/local/share/airnub/features/<feature>/compose.yaml` during install. The
metadata written to `/tmp/devcontainer-feature.json` allows the feature test tooling from the
[devcontainers/feature-starter](https://github.com/devcontainers/feature-starter) template to discover the output.

## Available features

| Feature ID | Purpose |
|------------|---------|
| `gui-novnc` | Ships the custom Chromium + noVNC sidecar used for the browser-accessible desktop. |
| `gui-webtop` | Registers the LinuxServer Webtop overlay to provide a full desktop-within-browser workflow. |
| `gui-chrome` | Adds the lightweight Chrome-only remote debugging sidecar for classroom and testing flows. |

## Consuming these features

1. Reference the feature from `devcontainer.json`:

   ```jsonc
   "features": {
     "ghcr.io/airnub-labs/features/gui-novnc:0.1.0": {}
   }
   ```

2. Mount the generated overlay inside your repository (Codespaces and `devcontainer up` support `${containerWorkspaceFolder}`):

   ```jsonc
   "mounts": [
     "source=/usr/local/share/airnub/features/gui-novnc/compose.yaml,target=${containerWorkspaceFolder}/.devcontainer/features/gui-novnc/compose.yaml,type=bind,consistency=cached"
   ]
   ```

3. Add the mounted file (alongside your copy of `containers/compose/base.yaml`) to the `dockerComposeFile` array for whichever profile you expose.

Publishing the feature bundle to GHCR makes it installable from any downstream repository without copying this
repository's internal structure.
