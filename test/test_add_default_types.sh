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
git init -q            # minimal repo

# blank config
echo '{}' > global.json

# build snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# run the flag
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --add-default-types

count=$(jq '.settings.types_tracked | length' global.json)
if [ "$count" -eq 41 ]; then
  echo "✅ --add-default-types added 41 built-in extensions"
else
  echo "❌ --add-default-types expected 41 entries, got $count" >&2
  exit 1
fi
