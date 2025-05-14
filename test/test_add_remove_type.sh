#!/usr/bin/env bash
#
# Validate --add-type/remove-type and their bare forms.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

###############################################################################
# 1. sample files
###############################################################################
echo 'plain text' > note.txt
echo 'console.log("hi");' > foo.js
echo '{}' > config.json

###############################################################################
# 2. assemble snapshot
###############################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

###############################################################################
# 3. ── PREFIX: --add-type/--remove-type ──
###############################################################################

echo "── PREFIX: --add-type/--remove-type ──"
echo '{}' > global.json
initial=$(snap | grep -c '^===== note.txt =====' || true)
snap --add-type txt >/dev/null
added1=$(snap --print | grep -c '^===== note.txt =====')
snap --remove-type txt >/dev/null
removed1=$(snap | grep -c '^===== note.txt =====' || true)

[ "$initial" -eq 0 ] &&
[ "$added1" -eq 1 ] &&
[ "$removed1" -eq 0 ] || {
  echo "  - add/remove-type (prefix) ❌"; exit 1
}
echo "  - add/remove-type (prefix) ✅"

###############################################################################
# 4. ── PREFIX: --add-type/--remove-type ──
###############################################################################

echo "── BARE: add-type/remove-type ──"
echo '{}' > global.json
snap add-type txt >/dev/null
added2=$(snap print | grep -c '^===== note.txt =====')
snap remove-type txt >/dev/null
removed2=$(snap | grep -c '^===== note.txt =====' || true)

[ "$added2" -eq 1 ] &&
[ "$removed2" -eq 0 ] || {
  echo "  - add/remove-type (bare) ❌"; exit 1
}
echo "  - add/remove-type (bare) ✅"

echo "✅ test/test_add_remove_type.sh"
