#!/usr/bin/env bash
#
# Verify that the installer correctly assembles & installs the script.
#
set -euo pipefail

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# fake a HOME so we don’t pollute the real user
export HOME="$tmpdir/home"
mkdir -p "$HOME"

# run installer
bash "$repo_root/install_snapshot.sh" >/dev/null

exe="$HOME/bin/snapshot"
[ -x "$exe" ] || { echo "❌ installer failed - binary not found." >&2; exit 1; }

# sanity‑check: default --config should print valid JSON
output=$("$exe" --config 2>/dev/null)
echo "$output" | jq -e type >/dev/null || {
  echo "❌ snapshot --config did not output JSON" >&2
  exit 1
}

echo "✅ installer produced working snapshot binary"
