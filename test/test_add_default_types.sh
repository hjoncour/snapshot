#!/usr/bin/env bash
#
# Ensure --add-default-types populates settings.types_tracked with 41 entries
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

###############################################################################
# 1. ── PREFIX: --add-default-types ──
###############################################################################

echo "── PREFIX: --add-default-types ──"
SNAPSHOT_CONFIG="$tmpdir/global.json" echo '{}' > global.json
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --add-default-types
count1=$(jq '.settings.types_tracked | length' global.json)
if [ "$count1" -eq 41 ]; then
  echo "  - add-default-types (prefix) ✅"
else
  echo "  - add-default-types (prefix) ❌ (got $count1)"
  exit 1
fi

###############################################################################
# 2. ── BARE: add-default-types ──
###############################################################################

echo "── BARE: add-default-types ──"
SNAPSHOT_CONFIG="$tmpdir/global.json" echo '{}' > global.json
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh add-default-types
count2=$(jq '.settings.types_tracked | length' global.json)
if [ "$count2" -eq 41 ]; then
  echo "  - add-default-types (bare) ✅"
else
  echo "  - add-default-types (bare) ❌ (got $count2)"
  exit 1
fi

echo "✅ test/test_add_default_types.sh"
