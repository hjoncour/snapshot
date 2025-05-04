#!/usr/bin/env bash
#
# Minimal test for “snapshot --config”.
# Run from repo root:  bash test/test_config.sh
#
set -euo pipefail

###############################################################################
# 0. locate the real repo before leaving it
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

###############################################################################
# 1. create a temporary git repo
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

cat > config.json <<'EOF'
{"foo":"bar"}
EOF

# copy snapshot into this repo
mkdir -p src
cp "$repo_root/src/snapshot.sh" src/snapshot.sh
chmod +x src/snapshot.sh

# Stage the files so git ls-files can see them
git add . >/dev/null

###############################################################################
# 2. run snapshot --config and compare output
###############################################################################
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
