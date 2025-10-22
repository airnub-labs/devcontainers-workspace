#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[install-supabase-cli] curl is required" >&2
  exit 1
fi

github_api_headers=(-H "Accept: application/vnd.github+json" -H "User-Agent: supabase-devcontainer-installer")
github_download_headers=(-H "Accept: application/octet-stream" -H "User-Agent: supabase-devcontainer-installer")

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  github_api_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  github_download_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

install_packages() {
  local packages=(ca-certificates tar)
  local missing=()
  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if ((${#missing[@]} > 0)); then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
    sudo rm -rf /var/lib/apt/lists/*
  fi
}

resolve_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      echo "[install-supabase-cli] Unsupported architecture: $arch" >&2
      return 1
      ;;
  esac
}

download_and_install() {
  local version="$1"
  local download_type="$2"
  local arch

  if ! arch="$(resolve_arch)"; then
    return 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap '[[ -n "${tmp_dir:-}" ]] && rm -rf "$tmp_dir"' RETURN

  local archive_url
  if [[ "$download_type" == "latest" ]]; then
    archive_url="https://github.com/supabase/cli/releases/latest/download/supabase_linux_${arch}.tar.gz"
  else
    archive_url="https://github.com/supabase/cli/releases/download/${version}/supabase_linux_${arch}.tar.gz"
  fi

  if ! curl -fsSL "${github_download_headers[@]}" -o "$tmp_dir/supabase.tar.gz" "$archive_url"; then
    echo "[install-supabase-cli] Warning: failed to download Supabase CLI archive from $archive_url" >&2
    return 1
  fi

  if ! tar -xzf "$tmp_dir/supabase.tar.gz" -C "$tmp_dir"; then
    echo "[install-supabase-cli] Warning: failed to extract Supabase CLI archive" >&2
    return 1
  fi

  if ! sudo install -m 755 "$tmp_dir/supabase" /usr/local/bin/supabase; then
    echo "[install-supabase-cli] Warning: failed to install Supabase CLI binary" >&2
    return 1
  fi
}

fetch_latest_version_via_api() {
  local api_url="https://api.github.com/repos/supabase/cli/releases/latest"
  local response

  if ! response="$(curl -fsSL "${github_api_headers[@]}" "$api_url" 2>/dev/null)"; then
    return 1
  fi

  local tag
  tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name", ""))' <<<"$response" 2>/dev/null)"
  if [[ -n "$tag" ]]; then
    echo "$tag"
    return 0
  fi

  return 1
}

fetch_latest_version_via_git() {
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  local latest
  latest="$(git ls-remote --tags --refs --sort='-v:refname' https://github.com/supabase/cli.git 'v*' 2>/dev/null | head -n1 | awk '{print $2}' | sed 's#refs/tags/##')"

  if [[ -n "$latest" ]]; then
    echo "$latest"
    return 0
  fi

  return 1
}

main() {
  install_packages

  local requested_version
  requested_version="${SUPABASE_VERSION:-latest}"

  local resolved_version=""
  local download_type="tag"

  if [[ "$requested_version" == "latest" ]]; then
    if resolved_version="$(fetch_latest_version_via_api)"; then
      download_type="tag"
    elif resolved_version="$(fetch_latest_version_via_git)"; then
      download_type="tag"
    else
      download_type="latest"
      echo "[install-supabase-cli] Warning: falling back to direct latest asset download; version information unavailable." >&2
    fi
  else
    if [[ "$requested_version" != v* ]]; then
      resolved_version="v${requested_version}"
    else
      resolved_version="$requested_version"
    fi
  fi

  if [[ "$download_type" == "tag" && -z "$resolved_version" ]]; then
    echo "[install-supabase-cli] ERROR: Supabase version could not be determined" >&2
    exit 1
  fi

  if download_and_install "$resolved_version" "$download_type"; then
    echo -n "[install-supabase-cli] Installed Supabase CLI version: "
    supabase --version
  else
    echo "[install-supabase-cli] Supabase CLI was not installed; continue manually if required." >&2
  fi
}

main "$@"
