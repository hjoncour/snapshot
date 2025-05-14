#!/usr/bin/env bash
#
# Validate remove-all-ignored* flags and bare forms.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT; cd "$tmpdir"; git init -q

jq -n '{ignore_file:["a","b"],ignore_path:["x","y"]}' > global.json
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
snap(){ SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

###############################################################################
# 1. ── PREFIX: --remove-all-ignored* ──
###############################################################################

echo "── PREFIX: --remove-all-ignored* ──"
snap --remove-all-ignored-files
files1=$(jq '.ignore_file|length' global.json)
paths1=$(jq '.ignore_path|length' global.json)
snap --remove-all-ignored-paths
files2=$(jq '.ignore_file|length' global.json)
paths2=$(jq '.ignore_path|length' global.json)
jq -n '{ignore_file:["a"],ignore_path:["b"]}' > global.json
snap --remove-all-ignored
files3=$(jq '.ignore_file|length' global.json)
paths3=$(jq '.ignore_path|length' global.json)

if [ "$files1" -eq 0 ] && [ "$paths1" -eq 2 ] \
  && [ "$files2" -eq 0 ] && [ "$paths2" -eq 0 ] \
  && [ "$files3" -eq 0 ] && [ "$paths3" -eq 0 ]; then
  echo "  - remove-all-ignored* (prefix) ✅"
else
  echo "  - remove-all-ignored* (prefix) ❌"; exit 1
fi

###############################################################################
# 2. ── BARE: remove-all-ignored* ──
###############################################################################

echo "── BARE: remove-all-ignored* ──"
jq -n '{ignore_file:["a","b"],ignore_path:["x","y"]}' > global.json
snap remove-all-ignored-files
f1=$(jq '.ignore_file|length' global.json); p1=$(jq '.ignore_path|length' global.json)
snap remove-all-ignored-paths
f2=$(jq '.ignore_file|length' global.json); p2=$(jq '.ignore_path|length' global.json)
jq -n '{ignore_file:["a"],ignore_path:["b"]}' > global.json
snap remove-all-ignored
f3=$(jq '.ignore_file|length' global.json); p3=$(jq '.ignore_path|length' global.json)

if [ "$f1" -eq 0 ] && [ "$p1" -eq 2 ] \
  && [ "$f2" -eq 0 ] && [ "$p2" -eq 0 ] \
  && [ "$f3" -eq 0 ] && [ "$p3" -eq 0 ]; then
  echo "  - remove-all-ignored* (bare) ✅"
else
  echo "  - remove-all-ignored* (bare) ❌"; exit 1
fi

echo "✅ test/test_remove_all_ignored_lists.sh"
