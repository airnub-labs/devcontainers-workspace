#!/usr/bin/env bash
set -euo pipefail

FEATURE_DIR="/usr/local/share/devcontainer/features/cuda-lite"
PROFILE_DIR="/etc/profile.d"
mkdir -p "${FEATURE_DIR}" "${PROFILE_DIR}"

if ! command -v nvidia-smi >/dev/null 2>&1; then
    cat <<'EOF_NOTE' >"${FEATURE_DIR}/feature-installed.txt"
status=skipped
reason=no-gpu-detected
EOF_NOTE
    cat <<'EOF_ENV' >"${PROFILE_DIR}/cuda-lite.sh"
export CUDA_AVAILABLE="false"
EOF_ENV
    exit 0
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nvidia-cuda-toolkit

cat <<'EOF_ENV' >"${PROFILE_DIR}/cuda-lite.sh"
export CUDA_AVAILABLE="true"
export PATH="/usr/lib/cuda/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/lib/cuda/lib64:${LD_LIBRARY_PATH:-}"
EOF_ENV

cat <<'EOF_NOTE' >"${FEATURE_DIR}/feature-installed.txt"
status=installed
package=nvidia-cuda-toolkit
EOF_NOTE
