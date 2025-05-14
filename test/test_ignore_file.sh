#!/usr/bin/env bash
#
# Validate --ignore and ignore alias.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# create a file that would normally be captured
echo "# test file" > foo.md
echo '{}' > config.json

# assemble snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null

snap() {
  SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"
}

###############################################################################
# 1. ── PREFIX: --ignore ──
###############################################################################

echo "── PREFIX: --ignore ──"
# before ignoring, foo.md should appear
before1=$(snap --print | grep -c '^===== foo.md =====')
[ "$before1" -eq 1 ] || { echo "  - before prefix ignore ❌"; exit 1; }

# add ignore and then re-run
snap --ignore foo.md >/dev/null
after1=$(snap --print | grep -c '^===== foo.md =====' || true)
[ "$after1" -eq 0 ] && echo "  - ignore (prefix) ✅" || {
  echo "  - ignore (prefix) ❌"; exit 1; }

###############################################################################
# 2. ── BARE: ignore ──
###############################################################################

echo "── BARE: ignore ──"
# reset config
echo '{}' > global.json

# before again
before2=$(snap print | grep -c '^===== foo.md =====')
[ "$before2" -eq 1 ] || { echo "  - before bare ignore ❌"; exit 1; }

# bare ignore
snap ignore foo.md >/dev/null
after2=$(snap print | grep -c '^===== foo.md =====' || true)
[ "$after2" -eq 0 ] && echo "  - ignore (bare) ✅" || {
  echo "  - ignore (bare) ❌"; exit 1; }

echo "✅ test/test_ignore_file.sh"
