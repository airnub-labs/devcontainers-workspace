#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"
MANAGE_LOCAL_STACK="${MANAGELOCALSTACK:-false}"
PROJECT_REF="${PROJECTREF:-}"
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
    curl -fsSL "https://api.github.com/repos/supabase/cli/releases/latest" \
        | grep -m1 '"tag_name"' \
        | cut -d '"' -f4
}

install_supabase_cli() {
    local requested
    requested=$(normalize_version "${VERSION}")

    if [ "${requested}" = "latest" ]; then
        requested=$(fetch_latest_tag)
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
    trap 'rm -rf "${tmp_deb}"' EXIT

    echo "[supabase-cli] Downloading ${deb_url}"
    curl -fsSL "${deb_url}" -o "${tmp_deb}/supabase.deb"

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${tmp_deb}/supabase.deb"

    rm -rf "${tmp_deb}"
    trap - EXIT
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

if [ "${MANAGE_LOCAL_STACK}" = "true" ]; then
    install_helper_scripts
fi

if [ -n "${PROJECT_REF}" ]; then
    mkdir -p "${PROFILE_DIR}"
    cat <<EOF_ENV >"${PROFILE_DIR}/supabase-cli.sh"
export SUPABASE_PROJECT_REF="${PROJECT_REF}"
EOF_ENV
fi

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
version=${VERSION}
manageLocalStack=${MANAGE_LOCAL_STACK}
projectRef=${PROJECT_REF}
EOF_NOTE
