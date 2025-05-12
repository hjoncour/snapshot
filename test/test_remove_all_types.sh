#!/usr/bin/env bash
#
# Verify that --remove-all-types empties settings.types_tracked
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# seed config with two custom types
jq -n '{"settings":{"types_tracked":["foo","bar"]}}' > global.json

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --remove-all-types

len=$(jq '.settings.types_tracked | length' global.json)
if [ "$len" -eq 0 ]; then
  echo "✅ --remove-all-types cleared list"
else
  echo "❌ --remove-all-types failed (length=$len)" >&2
  exit 1
fi
