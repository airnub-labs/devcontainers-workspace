#!/bin/sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FEATURE_DIR=/usr/local/share/airnub/features/gui-chrome
mkdir -p "$FEATURE_DIR"

cp "$SCRIPT_DIR/../assets/compose.yaml" "$FEATURE_DIR/compose.yaml"
mkdir -p "$FEATURE_DIR/assets/gui"
cp "$SCRIPT_DIR/../assets/gui/chrome-devtools.sh" "$FEATURE_DIR/assets/gui/chrome-devtools.sh"

cat <<JSON > "$FEATURE_DIR/options.json"
{
  "headless": ${HEADLESS:-false}
}
JSON

cat <<'TXT' > "$FEATURE_DIR/README.md"
The Chrome desktop sidecar overlay pairs with the airnub workspace so that developers can attach DevTools from an
iPad or Chromebook. Combine this overlay with the base compose file and forward ports 3002/9224 in your
configuration.
TXT

chmod 0644 "$FEATURE_DIR/compose.yaml" "$FEATURE_DIR/options.json" "$FEATURE_DIR/README.md"
chmod +x "$FEATURE_DIR/assets/gui/chrome-devtools.sh"

cat <<EOF >/tmp/devcontainer-feature.json
{"composeOverlay":"$FEATURE_DIR/compose.yaml","assetsRoot":"$FEATURE_DIR/assets"}
EOF
