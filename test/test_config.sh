#!/usr/bin/env bash
#
# Minimal test for “snapshot --config”.
# Run from the repo root:  bash tests/test_config.sh
#
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

################################################################################
# 1. create throw‑away git repo + files
################################################################################
cd "$tmpdir"
git init -q

cat > config.json <<'EOF'
{"foo":"bar"}
EOF

# copy snapshot script from the real repo into the temp repo
mkdir -p src
cp "$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)/src/snapshot.sh" src/snapshot.sh
chmod +x src/snapshot.sh

git add .
git commit -qm "init test repo"

################################################################################
# 2. run snapshot --config and compare output
################################################################################
output=$(bash src/snapshot.sh --config)
expected='{"foo":"bar"}'

if [ "$output" = "$expected" ]; then
  echo "✅ snapshot --config returned config.json"
else
  echo "❌ snapshot --config returned unexpected output"
  echo "expected: $expected"
  echo "got:      $output"
  exit 1
fi
