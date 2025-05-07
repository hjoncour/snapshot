#!/usr/bin/env bash
#
# Validate the --ignore feature.
#
set -euo pipefail

# locate real repo
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# create a file that would normally be captured
echo "# test file" > foo.md
echo '{}' > config.json             # blank project config

# copy snapshot
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null                # so git ls-files sees them

# 1. confirm foo.md is present
before=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh code | grep -c '^===== foo.md =====')
[ "$before" -eq 1 ] || { echo "❌ setup error - foo.md not found." >&2; exit 1; }

# 2. ignore it
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --ignore foo.md

# 3. run again, confirm foo.md gone
after=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh code | grep -c '^===== foo.md =====' || true)
if [ "$after" -eq 0 ]; then
  echo "✅ ignore_file works (foo.md skipped)"
else
  echo "❌ ignore_file failed - foo.md still present" >&2
  exit 1
fi
