#!/usr/bin/env bash
#
# Verify remove-all-types flag and bare form.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT; cd "$tmpdir"; git init -q

jq -n '{"settings":{"types_tracked":["foo","bar"]}}' > global.json
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
###############################################################################
# 1. ── PREFIX: --remove-all-types ──
###############################################################################

echo "── PREFIX: --remove-all-types ──"
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --remove-all-types
len1=$(jq '.settings.types_tracked|length' global.json)
[ "$len1" -eq 0 ] && echo "  - remove-all-types (prefix) ✅" || {
  echo "  - remove-all-types (prefix) ❌"; exit 1; }

###############################################################################
# 2. ── BARE: remove-all-types ──
###############################################################################

echo "── BARE: remove-all-types ──"
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh remove-all-types
len2=$(jq '.settings.types_tracked|length' global.json)
[ "$len2" -eq 0 ] && echo "  - remove-all-types (bare) ✅" || {
  echo "  - remove-all-types (bare) ❌"; exit 1; }

echo "✅ test/test_remove_all_types.sh"
