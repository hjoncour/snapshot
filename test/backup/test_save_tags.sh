#!/usr/bin/env bash
#
# test_tags.sh — Validate --tag flag functionality
#
set -euo pipefail

###############################################################################
# Setup: isolated HOME and config
###############################################################################
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME="$tmp_home"

# Prepare support directory and global config
mkdir -p "$HOME/Library/Application Support/snapshot"
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{ "project":"demo" }' > "$SNAPSHOT_CONFIG"

###############################################################################
# Initialize a sample Git repository with a test file
###############################################################################
cd "$tmp_home"
git init -q
echo "console.log('test');" > foo.js
echo '{}' > config.json
git add . >/dev/null

###############################################################################
# Install the snapshot stub
###############################################################################
repo_root="$(git -C "$PWD" rev-parse --show-toplevel)"
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

snap() { SNAPSHOT_CONFIG="$SNAPSHOT_CONFIG" bash src/snapshot.sh "$@"; }

###############################################################################
# 1) Single file, two tags
###############################################################################
echo "→ single file, two tags"
snap --name one --tag t1 t2 >/dev/null
file1="$HOME/Library/Application Support/snapshot/demo/one__t1_t2.snapshot"
[ -f "$file1" ] || { echo "❌ expected $file1"; exit 1; }

###############################################################################
# 2) Multiple files, two tags
###############################################################################
echo "→ multiple files, two tags"
snap --name a b --tag x y >/dev/null
fileA="$HOME/Library/Application Support/snapshot/demo/a__x_y.snapshot"
fileB="$HOME/Library/Application Support/snapshot/demo/b__x_y.snapshot"
[ -f "$fileA" ] || { echo "❌ expected $fileA"; exit 1; }
[ -f "$fileB" ] || { echo "❌ expected $fileB"; exit 1; }

###############################################################################
# 3) Multiple files, tags, --print and --copy
###############################################################################
echo "→ multiple files + tags + --print + --copy"
output="$(snap --name c d --tag z w --print --copy)"
fileC="$HOME/Library/Application Support/snapshot/demo/c__z_w.snapshot"
fileD="$HOME/Library/Application Support/snapshot/demo/d__z_w.snapshot"
[ -f "$fileC" ] || { echo "❌ expected $fileC"; exit 1; }
[ -f "$fileD" ] || { echo "❌ expected $fileD"; exit 1; }

echo "$output" | grep -q '^===== foo.js =====' || { echo "❌ missing dump"; exit 1; }
echo "$output" | grep -q 'snapshot: copied [0-9]\+ bytes to clipboard' || { echo "❌ missing copy confirmation"; exit 1; }

echo "✅ tag tests passed"
