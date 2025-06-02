#!/usr/bin/env bash
#
# test_install.sh – verify that the installer
#   • creates a working snapshot binary
#   • bumps the version in an existing global config
#   • still prints parseable JSON from `snapshot --config`
#
set -euo pipefail

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
template_version=$(jq -r '.version' "$repo_root/config.json")

tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME="$tmp_home"

cfg_dir="$HOME/Library/Application Support/snapshot"
mkdir -p "$cfg_dir"
cat >"$cfg_dir/config.json" <<'EOF'
{
  "version": "0.0.0.0",
  "user_key": "should_be_preserved"
}
EOF

###############################################################################
# 1. run the installer
###############################################################################
bash "$repo_root/install_snapshot.sh" >/dev/null
exe="$HOME/bin/snapshot"

[ -x "$exe" ] || { echo "❌ installer failed – binary not found." >&2; exit 1; }

###############################################################################
# 2. validate updated global config
###############################################################################
updated_cfg="$cfg_dir/config.json"

new_version=$(jq -r '.version' "$updated_cfg")
if [[ "$new_version" != "$template_version" ]]; then
  echo "❌ installer did NOT bump version (expected $template_version, got $new_version)" >&2
  exit 1
fi

jq -e '.user_key == "should_be_preserved"' "$updated_cfg" >/dev/null || {
  echo "❌ installer overwrote custom keys in config.json" >&2
  exit 1
}

###############################################################################
# 3. snapshot --config must still be machine-readable after stripping comments
###############################################################################
raw_cfg=$("$exe" --config)
clean_cfg=$(printf '%s\n' "$raw_cfg" | sed -E 's/[[:space:]]*\/\/.*$//')
echo "$clean_cfg" | jq -e type >/dev/null || {
  echo "❌ snapshot --config no longer yields parseable JSON" >&2
  exit 1
}

echo "✅ installer updates version, preserves keys, and config output is parseable"
