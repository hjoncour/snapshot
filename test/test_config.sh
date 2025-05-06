#!/usr/bin/env bash
#
# Minimal test for “snapshot --config”.
#
# Pass criteria:
#   • output is valid JSON
#   • key .foo equals "bar"
#
set -euo pipefail

###############################################################################
# 0. locate real repo
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

###############################################################################
# 1. create temporary git repo
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# ----- GLOBAL config that snapshot should print -----
cat > global.json <<'EOF'
{"foo":"bar"}
EOF

# project‑local config (not used in this test, but harmless)
echo '{}' > config.json

# copy snapshot into this repo
mkdir -p src
cp "$repo_root/src/snapshot.sh" src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null   # so git ls-files works

###############################################################################
# 2. run snapshot --config with overridden global path
###############################################################################
output=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --config)

# 3. validate
if ! echo "$output" | jq . >/dev/null 2>&1; then
  echo "❌ snapshot --config did not return valid JSON" >&2
  exit 1
fi

foo_val=$(echo "$output" | jq -r '.foo // empty')
if [[ "$foo_val" == "bar" ]]; then
  echo "✅ snapshot --config returned expected key foo=bar"
else
  echo "❌ snapshot --config returned unexpected .foo value" >&2
  echo "got: '$foo_val'" >&2
  exit 1
fi
