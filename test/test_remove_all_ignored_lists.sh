#!/usr/bin/env bash
#
# Validate the three “remove-all” ignore flags.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# seed config with entries in both lists
jq -n '{
  ignore_file:["foo.md","bar.txt"],
  ignore_path:["dir/*","*.secret"]
}' > global.json

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

###############################################################################
# 1. clear ONLY files
###############################################################################
snap --remove-all-ignored-files
files_len=$(jq '.ignore_file | length' global.json)
paths_len=$(jq '.ignore_path | length' global.json)
[ "$files_len" -eq 0 ] && [ "$paths_len" -eq 2 ] || {
  echo "❌ --remove-all-ignored-files did not work as expected" >&2; exit 1; }

###############################################################################
# 2. clear ONLY paths
###############################################################################
snap --remove-all-ignored-paths
files_len=$(jq '.ignore_file | length' global.json)
paths_len=$(jq '.ignore_path | length' global.json)
[ "$files_len" -eq 0 ] && [ "$paths_len" -eq 0 ] || {
  echo "❌ --remove-all-ignored-paths failed" >&2; exit 1; }

###############################################################################
# 3. re-seed and clear BOTH lists
###############################################################################
jq '.ignore_file=["a"] | .ignore_path=["b"]' global.json > tmp && mv tmp global.json
snap --remove-all-ignored
tot_files=$(jq '.ignore_file | length' global.json)
tot_paths=$(jq '.ignore_path | length' global.json)
[ "$tot_files" -eq 0 ] && [ "$tot_paths" -eq 0 ] || {
  echo "❌ --remove-all-ignored failed" >&2; exit 1; }

echo "✅ remove-all ignore flags work correctly"
