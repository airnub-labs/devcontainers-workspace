#!/usr/bin/env bash
set -euo pipefail

SCORE=$(grep SCORE_TOTAL .score/summary.env | cut -d= -f2)
echo "# Devcontainers Alignment Report"
echo
echo "**Repository:** airnub-labs/vscode-meta-workspace-internal@refactor-2"
echo
echo "**Total Score:** ${SCORE}/100"
echo
echo "## Breakdown"
echo
while read -r line; do
  echo "- $line"
done < .score/details.txt

echo
echo "## Summary & Recommendations"
echo
# Simple heuristics -> suggestions
if ! grep -q "Features: structure OK" .score/details.txt; then
  echo "- Create \`features/<id>/\` directories with \`devcontainer-feature.json\` + \`install.sh\` per feature (Supabase CLI, Chrome CDP, MCP CLIs, etc.)."
fi
if ! grep -q "Templates: structure OK" .score/details.txt; then
  echo "- Add \`templates/<name>/devcontainer-template.json\` and \`templates/<name>/.template/.devcontainer/devcontainer.json\`."
fi
if ! grep -q "compose multi-container present" .score/details.txt; then
  echo "- For classroom/iPad, add a sidecar browser: \`dockerComposeFile\` + \`service\` + \`runServices\` with a \`webtop\` service and labeled ports."
fi
if ! grep -q "publish-features present" .score/details.txt; then
  echo "- Add CI workflow using \`devcontainers/action\` to publish Features to GHCR as OCI artifacts."
fi
if ! grep -q "Docs: " .score/details.txt; then
  echo "- Document spec alignment in \`docs/SPEC-ALIGNMENT.md\`, plus \`CATALOG.md\`, \`EDU-SETUP.md\`, \`SECURITY.md\`."
fi

echo
echo "## Spec references"
echo "- Features authoring & distribution: containers.dev (Features guide) and devcontainers/feature-starter."
echo "- Templates authoring & distribution: containers.dev Templates, devcontainers/templates & template-starter repos."
