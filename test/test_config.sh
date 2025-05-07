#!/usr/bin/env bash
#
# Minimal test for “snapshot --config”.
#
set -euo pipefail

###############################################################################
# 0. locate the real repo so we can copy snapshot.sh from it
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

###############################################################################
# 1. create a temporary git repo *and* a custom global config
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# project‑local config (not used by --config any more, but harmless)
echo '{}' > config.json

# custom global config that snapshot should print
cat > global.json <<'EOF'
{"foo":"bar"}
EOF

# copy snapshot into this repo
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null   # so git ls-files works

###############################################################################
# 2. run snapshot --config and compare output
###############################################################################
expected='{"foo":"bar"}'
output=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --config)

if [[ "$output" == "$expected" ]]; then
  echo "✅ snapshot --config returned overridden global config"
else
  echo "❌ snapshot --config returned unexpected output"
  echo "expected: $expected"
  echo "got:      $output"
  exit 1
fi
