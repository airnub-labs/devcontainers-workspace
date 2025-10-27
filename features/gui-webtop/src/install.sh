#!/bin/sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FEATURE_DIR=/usr/local/share/airnub/features/gui-webtop
mkdir -p "$FEATURE_DIR"

cp "$SCRIPT_DIR/../assets/compose.yaml" "$FEATURE_DIR/compose.yaml"
mkdir -p "$FEATURE_DIR/assets/gui"
cp "$SCRIPT_DIR/../assets/gui/webtop-devtools.sh" "$FEATURE_DIR/assets/gui/webtop-devtools.sh"

cat <<JSON > "$FEATURE_DIR/options.json"
{
  "audio": ${AUDIO:-true}
}
JSON

cat <<'TXT' > "$FEATURE_DIR/README.md"
This feature stores the LinuxServer Webtop compose overlay used by the airnub workspace. Copy the compose.yaml file
into your consuming repository or reference it via a Git submodule to enable a browser-accessible desktop from
Codespaces and Dev Containers.
TXT

chmod 0644 "$FEATURE_DIR/compose.yaml" "$FEATURE_DIR/options.json" "$FEATURE_DIR/README.md"
chmod +x "$FEATURE_DIR/assets/gui/webtop-devtools.sh"

cat <<EOF >/tmp/devcontainer-feature.json
{"composeOverlay":"$FEATURE_DIR/compose.yaml","assetsRoot":"$FEATURE_DIR/assets"}
EOF
