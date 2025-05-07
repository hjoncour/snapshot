#!/usr/bin/env bash
#
# Validate the ignore_path feature (path + glob patterns).
#
set -euo pipefail

# 0. locate repo root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

# 1. create temp repo
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# test files
mkdir -p demo_dir
echo "console.log('hi');" > demo_dir/foo.js
echo "secret data"        > .secret-pass.sh
echo "sample content"     > test.sample.js
echo "keep this"          > keep.sh

echo '{}' > config.json

# copy snapshot script
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# stage files explicitly
git add -f demo_dir/foo.js .secret-pass.sh test.sample.js keep.sh config.json >/dev/null

# helper to run snapshot
snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

# 2. ensure initial presence
output="$(snap code)"
for needle in \
  "===== demo_dir/foo.js =====" \
  "===== .secret-pass.sh =====" \
  "===== test.sample.js ====="
do
  echo "$output" | grep -Fq "$needle" || {
    echo "❌ setup error – expected '$needle' in initial dump." >&2
    echo "Dump was:" >&2
    echo "$output" >&2
    exit 1
  }
done

# 3. add ignore_path patterns
snap --ignore 'demo_dir/*' '.secret-*' '**.sample.js' >/dev/null

# 4. ensure files are now excluded
output2="$(snap code)"
for banned in \
  "===== demo_dir/foo.js =====" \
  "===== .secret-pass.sh =====" \
  "===== test.sample.js ====="
do
  if echo "$output2" | grep -Fq "$banned"; then
    echo "❌ ignore_path failed – still saw '$banned'" >&2
    echo "Dump was:" >&2
    echo "$output2" >&2
    exit 1
  fi
done

echo "✅ ignore_path patterns correctly excluded files"
