#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"
MANAGE_LOCAL_STACK="${MANAGELOCALSTACK:-false}"
PROJECT_REF="${PROJECTREF:-}"
SERVICES_RAW="${SERVICES:-}"
FEATURE_DIR="/usr/local/share/devcontainer/features/supabase-cli"
BIN_DIR="/usr/local/bin"
PROFILE_DIR="/etc/profile.d"

mkdir -p "${FEATURE_DIR}"

normalize_version() {
    local raw="$1"
    if [ -z "${raw}" ] || [ "${raw}" = "latest" ]; then
        echo "latest"
        return 0
    fi
    if [[ "${raw}" == v* ]]; then
        echo "${raw}"
    else
        echo "v${raw}"
    fi
}

fetch_latest_tag() {
    python3 - <<'PYTHON'
import json
import sys
import urllib.error
import urllib.request

API_URL = "https://api.github.com/repos/supabase/cli/releases/latest"
HEADERS = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "devcontainers-feature-supabase-cli",
}

request = urllib.request.Request(API_URL, headers=HEADERS)

try:
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise urllib.error.HTTPError(
                API_URL,
                response.status,
                f"unexpected status: {response.status}",
                response.headers,
                None,
            )
        payload = json.load(response)
except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:  # pragma: no cover - defensive
    print(exc, file=sys.stderr)
    sys.exit(1)

tag = payload.get("tag_name")
if not tag:
    print("missing tag_name in Supabase release payload", file=sys.stderr)
    sys.exit(1)

print(tag)
PYTHON
}

install_supabase_cli() {
    local requested
    requested=$(normalize_version "${VERSION}")

    if [ "${requested}" = "latest" ]; then
        if ! requested=$(fetch_latest_tag); then
            echo "[supabase-cli] Failed to determine latest Supabase CLI release tag." >&2
            exit 1
        fi
    fi

    local arch
    arch=$(dpkg --print-architecture)
    case "${arch}" in
        amd64|arm64)
            ;;
        *)
            echo "[supabase-cli] Unsupported architecture: ${arch}" >&2
            exit 1
            ;;
    esac

    local current_version=""
    if command -v supabase >/dev/null 2>&1; then
        current_version=$(supabase --version | awk '{print $NF}')
        current_version="v${current_version#v}"
    fi

    if [ "${current_version}" = "${requested}" ]; then
        echo "[supabase-cli] Supabase CLI ${requested} already installed. Skipping."
        return 0
    fi

    local deb_url="https://github.com/supabase/cli/releases/download/${requested}/supabase_${requested#v}_linux_${arch}.deb"
    local tmp_deb
    tmp_deb=$(mktemp -d)
    trap 'rm -rf "${tmp_deb:-}"' EXIT

    echo "[supabase-cli] Downloading ${deb_url}"
    curl -fsSL "${deb_url}" -o "${tmp_deb}/supabase.deb"

    apt-get update

    local log_file="/tmp/supabase-cli-install.log"
    : >"${log_file}"

    if ! DEBIAN_FRONTEND=noninteractive dpkg -i "${tmp_deb}/supabase.deb" >"${log_file}" 2>&1; then
        echo "[supabase-cli] Resolving Supabase CLI dependencies (see ${log_file})"
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f \
            >>"${log_file}" 2>&1
        DEBIAN_FRONTEND=noninteractive dpkg -i "${tmp_deb}/supabase.deb" >>"${log_file}" 2>&1
    fi

    if [ ! -s "${log_file}" ]; then
        rm -f "${log_file}"
    fi

    rm -rf "${tmp_deb}"
    trap - EXIT
}

resolve_services() {
    python3 - <<'PYTHON'
import json
import os

services = []
raw = os.environ.get("SERVICES_RAW", "").strip()
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            services.extend(str(item) for item in parsed)
        elif isinstance(parsed, str):
            services.append(parsed)
    except json.JSONDecodeError:
        services.extend(part.strip() for part in raw.split(',') if part.strip())

for key, value in sorted(os.environ.items()):
    if key.startswith("SERVICES__") and value:
        services.append(value)

seen = []
for item in services:
    if item not in seen:
        seen.append(item)

if seen:
    print(",".join(seen))
PYTHON
}

install_helper_scripts() {
    cat <<'SCRIPT' >"${BIN_DIR}/sbx-start"
#!/usr/bin/env bash
set -euo pipefail
exec supabase start "$@"
SCRIPT
    chmod +x "${BIN_DIR}/sbx-start"

    cat <<'SCRIPT' >"${BIN_DIR}/sbx-stop"
#!/usr/bin/env bash
set -euo pipefail
exec supabase stop "$@"
SCRIPT
    chmod +x "${BIN_DIR}/sbx-stop"

    cat <<'SCRIPT' >"${BIN_DIR}/sbx-status"
#!/usr/bin/env bash
set -euo pipefail
exec supabase status "$@"
SCRIPT
    chmod +x "${BIN_DIR}/sbx-status"
}

install_supabase_cli

if [ -n "${PROJECT_REF}" ]; then
    mkdir -p "${PROFILE_DIR}"
    cat <<EOF_ENV >"${PROFILE_DIR}/supabase-cli.sh"
export SUPABASE_PROJECT_REF="${PROJECT_REF}"
EOF_ENV
else
    rm -f "${PROFILE_DIR}/supabase-cli.sh"
fi

if [ "${MANAGE_LOCAL_STACK}" = "true" ]; then
    install_helper_scripts
else
    rm -f "${BIN_DIR}/sbx-start" "${BIN_DIR}/sbx-stop" "${BIN_DIR}/sbx-status"
fi

SERVICES_LIST="$(SERVICES_RAW="${SERVICES_RAW}" resolve_services)"

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
version=${VERSION}
manageLocalStack=${MANAGE_LOCAL_STACK}
projectRef=${PROJECT_REF}
services=${SERVICES_LIST}
EOF_NOTE
