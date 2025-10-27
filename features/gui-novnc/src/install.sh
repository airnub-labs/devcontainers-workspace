#!/bin/sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FEATURE_DIR=/usr/local/share/airnub/features/gui-novnc
mkdir -p "$FEATURE_DIR"

cp "$SCRIPT_DIR/../assets/compose.yaml" "$FEATURE_DIR/compose.yaml"
mkdir -p "$FEATURE_DIR/image/scripts"
cp "$SCRIPT_DIR/../assets/image/Dockerfile" "$FEATURE_DIR/image/Dockerfile"
cp "$SCRIPT_DIR/../assets/image/scripts"/*.sh "$FEATURE_DIR/image/scripts/"

cat <<JSON > "$FEATURE_DIR/options.json"
{
  "audio": ${AUDIO:-true},
  "applyChromePolicy": ${APPLYCHROMEPOLICY:-false},
  "reduceFluxboxMenu": ${REDUCEFLUXBOXMENU:-false}
}
JSON

cat <<'TXT' > "$FEATURE_DIR/README.md"
This feature packages the airnub noVNC desktop sidecar. The accompanying Compose overlay is stored next to this
README so it can be checked into a Codespace or Dev Container configuration without copying the entire workspace.

To enable the overlay from a consuming repository, reference the file with:

  "dockerComposeFile": [
    "${localWorkspaceFolder}/.devcontainer/compose/base.yaml",
    "${localWorkspaceFolder}/.devcontainer/features/gui-novnc/compose.yaml"
  ]

and forward the ports listed in compose.yaml. Options chosen at install time are saved in options.json for auditing.
TXT

chmod 0644 "$FEATURE_DIR/compose.yaml" "$FEATURE_DIR/options.json" "$FEATURE_DIR/README.md"
chmod +x "$FEATURE_DIR/image/scripts"/*.sh

cat <<EOF >/tmp/devcontainer-feature.json
{"composeOverlay":"$FEATURE_DIR/compose.yaml","assetsRoot":"$FEATURE_DIR"}
EOF
