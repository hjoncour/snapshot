#!/usr/bin/env bash
#
# test_install.sh - verify that the installer
#   1) creates a working snapshot binary
#   2) *updates* an existing global config’s version field to the template’s
#
set -euo pipefail

###############################################################################
# 0. Locate the real repository (needed to run make_snapshot.sh + read template)
###############################################################################
repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"

template_version=$(jq -r '.version' "$repo_root/config.json")

###############################################################################
# 1. Prepare an isolated HOME with a *pre-existing* (old) config.json
###############################################################################
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME="$tmp_home"

cfg_dir="$HOME/Library/Application Support/snapshot"
mkdir -p "$cfg_dir"

old_cfg="$cfg_dir/config.json"
cat >"$old_cfg" <<'EOF'
{
  "version": "0.0.0.0",
  "user_key": "should_be_preserved"
}
EOF

###############################################################################
# 2. Run the installer
###############################################################################
bash "$repo_root/install_snapshot.sh" >/dev/null

exe="$HOME/bin/snapshot"
[ -x "$exe" ] || { echo "❌ installer failed - binary not found." >&2; exit 1; }

###############################################################################
# 3. Assertions on the *updated* global config
###############################################################################
updated_cfg="$cfg_dir/config.json"

# a) version field must now match the template’s version
new_version=$(jq -r '.version'        "$updated_cfg")
if [[ "$new_version" != "$template_version" ]]; then
  echo "❌ installer did NOT bump version (expected $template_version, got $new_version)" >&2
  exit 1
fi

# b) any pre-existing custom keys must still be there
jq -e '.user_key == "should_be_preserved"' "$updated_cfg" >/dev/null || {
  echo "❌ installer overwrote custom keys in config.json" >&2
  exit 1
}

# c) sanity-check: snapshot --config still emits valid JSON
"$exe" --config | jq -e type >/dev/null || {
  echo "❌ snapshot --config no longer outputs valid JSON" >&2
  exit 1
}

echo "✅ installer updates version & preserves existing keys"
