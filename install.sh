#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
require_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root (login as root, or use sudo if it exists)."; }

require_root

REPO="${REPO:-changecoin938/warp-multi-xui}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -e "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fi

if [[ -n "${SCRIPT_DIR:-}" ]] && [[ -f "${SCRIPT_DIR}/warp-multi" ]]; then
  install -m 0755 "${SCRIPT_DIR}/warp-multi" /usr/local/bin/warp-multi
else
  curl -fsSL "${RAW_BASE}/warp-multi" -o /usr/local/bin/warp-multi
  chmod +x /usr/local/bin/warp-multi
fi

if [[ "${1:-}" == "--no-run" ]]; then
  echo "Installed /usr/local/bin/warp-multi (not running install)."
  exit 0
fi

exec /usr/local/bin/warp-multi install "$@"

