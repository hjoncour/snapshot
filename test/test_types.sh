#!/usr/bin/env bash
#
# Validate --add-type and --remove-type behaviour.
#
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"; git init -q

echo "dummy" > bar.foo     # .foo extension initially untracked
echo '{}'   > config.json

mkdir -p src
cp "$repo_root/src/snapshot.sh" src/snapshot.sh; chmod +x src/snapshot.sh
git add bar.foo config.json >/dev/null

run() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

# 1. .foo should NOT appear
run code | grep -q '^===== bar.foo =====' && { echo "❌ .foo unexpectedly tracked"; exit 1; }

# 2. add type
run --add-type foo
run code | grep -q '^===== bar.foo =====' || { echo "❌ .foo not tracked after add"; exit 1; }

# 3. remove type
run --remove-type foo
run code | grep -q '^===== bar.foo =====' && { echo "❌ .foo still tracked after remove"; exit 1; }

echo "✅ add/remove-type works"
