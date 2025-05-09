#!/usr/bin/env bash
#
# Validate --add-type and --remove-type commands.
#
set -euo pipefail

# locate repo root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

###############################################################################
# 1. sample files
###############################################################################
echo 'plain text' > note.txt          # to be toggled on/off
echo 'console.log("hi");' > foo.js    # stays tracked by default
echo '{}' > config.json

###############################################################################
# 2. assemble snapshot
###############################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null   # make ls-files list our samples

# helper
snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

###############################################################################
# 3. create empty global config (no custom list → txt should be excluded)
###############################################################################
echo '{}' > global.json
initial=$(snap code | grep -c '^===== note.txt =====' || true)
[ "$initial" -eq 0 ] || { echo "❌ setup error - note.txt unexpectedly present." >&2; exit 1; }

###############################################################################
# 4. add txt type, confirm inclusion
###############################################################################
snap --add-type txt >/dev/null
added=$(snap --print code | grep -c '^===== note.txt =====')
[ "$added" -eq 1 ] || { echo "❌ --add-type failed - note.txt still missing." >&2; exit 1; }

###############################################################################
# 5. remove txt type, confirm exclusion again
###############################################################################
snap --remove-type txt >/dev/null
removed=$(snap code | grep -c '^===== note.txt =====' || true)
[ "$removed" -eq 0 ] || { echo "❌ --remove-type failed - note.txt still present." >&2; exit 1; }

echo "✅ --add-type / --remove-type work as expected"
