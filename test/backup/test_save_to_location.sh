#!/usr/bin/env bash
#
# Validate --to destination directory behaviour:
#   1) single file, single destination (absolute + relative)
#   2) multiple files, single destination (absolute + relative)
#   3) multiple files, multiple destinations (absolute)
#
set -euo pipefail

###############################################################################
# 0. Locate repo root (needed to run make_snapshot.sh)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Create isolated temp repo & helper
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

echo "console.log('hi');" > foo.js
echo '{}' > config.json
git add . >/dev/null

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# Helper: invoke snapshot with isolated global config
snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

printf '{}' > global.json   # start with empty global config

###############################################################################
# 2-A. ABSOLUTE destinations
###############################################################################
abs1="$tmpdir/abs_dest1"
snap --name one --to "$abs1" >/dev/null
[ -f "$abs1/one.snapshot" ] || { echo "❌ 1 file / 1 abs dest"; exit 1; }
echo "✅ 1 file / 1 abs dest"

abs2="$tmpdir/abs_dest2"
snap --name two three --to "$abs2" >/dev/null
for n in two three; do
  [ -f "$abs2/${n}.snapshot" ] || { echo "❌ 2 files / 1 abs dest"; exit 1; }
done
echo "✅ 2 files / 1 abs dest"

abs3="$tmpdir/abs_dest3"
abs4="$tmpdir/abs_dest4"
snap --name four five --to "$abs3" "$abs4" >/dev/null
for d in "$abs3" "$abs4"; do
  for n in four five; do
    [ -f "$d/${n}.snapshot" ] || { echo "❌ 2 files / 2 abs dests"; exit 1; }
  done
done
echo "✅ 2 files / 2 abs dests"

###############################################################################
# 2-B. RELATIVE destinations (within the repo root)
###############################################################################
rel1="rel_dest1"
snap --name six --to "$rel1" >/dev/null
[ -f "$rel1/six.snapshot" ] || { echo "❌ 1 file / 1 rel dest"; exit 1; }
echo "✅ 1 file / 1 rel dest"

rel2="rel_dest2"
snap --name seven eight --to "$rel2" >/dev/null
for n in seven eight; do
  [ -f "$rel2/${n}.snapshot" ] || { echo "❌ 2 files / 1 rel dest"; exit 1; }
done
echo "✅ 2 files / 1 rel dest"

###############################################################################
# 3. Done
###############################################################################
echo "✅ --to destination tests passed"
