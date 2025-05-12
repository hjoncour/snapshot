#!/usr/bin/env bash
#
# Validate that snapshots for different project names go into separate directories
#
set -euo pipefail

# locate repo root to assemble the snapshot binary
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

# prepare isolated HOME
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME="$tmp_home"

# point snapshot at an isolated config
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{}' > "$SNAPSHOT_CONFIG"

# ensure support dir exists
mkdir -p "$HOME/Library/Application Support/snapshot"

# prepare a simple git repo
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' RETURN
cd "$workdir"
git init -q
echo "console.log('hello');" > foo.js
echo '{}' > config.json
git add . >/dev/null

# install the snapshot script stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# 1) project name "app1"
jq -n --arg p "app1" '{project: $p}' > "$SNAPSHOT_CONFIG"
bash src/snapshot.sh code >/dev/null

dir1="$HOME/Library/Application Support/snapshot/app1"
files1=( "$dir1"/* )
[ -d "$dir1" ] || { echo "❌ app1 directory not created"; exit 1; }
[ "${#files1[@]}" -eq 1 ] || { echo "❌ expected 1 snapshot in $dir1, got ${#files1[@]}"; exit 1; }

# 2) project name "app2"
jq -n --arg p "app2" '{project: $p}' > "$SNAPSHOT_CONFIG"
bash src/snapshot.sh code >/dev/null

dir2="$HOME/Library/Application Support/snapshot/app2"
files2=( "$dir2"/* )
[ -d "$dir2" ] || { echo "❌ app2 directory not created"; exit 1; }
[ "${#files2[@]}" -eq 1 ] || { echo "❌ expected 1 snapshot in $dir2, got ${#files2[@]}"; exit 1; }

echo "✅ snapshots for different projects go into separate directories"
