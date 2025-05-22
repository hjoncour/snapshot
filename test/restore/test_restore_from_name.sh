#!/usr/bin/env bash
#
# test_restore_specific.sh – ensure that:
#     snapshot restore  <NAME>
#     snapshot --restore <NAME|NAME.snapshot>
# restore exactly the snapshot requested.
#
set -euo pipefail

###############################################################################
# 0. Locate repo root (to build the stub once)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Isolated HOME + tiny Git repo
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
mkdir -p "$HOME"

cd "$tmpdir"
git init -q

# ----  ensure commits succeed even in CI  -----------------------------------
git config user.email 'ci@example.com'
git config user.name  'CI Test'

###############################################################################
# 2. Initial file (v1) → snapshot “first”
###############################################################################
echo 'console.log("v1");' > foo.js
echo '{}' > config.json
git add foo.js config.json
git commit -m "v1" -q

# Build one-file snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

# Global config with project name → snapshots in …/snapshot/demo/
echo '{"project":"demo"}' > "$tmpdir/global.json"

snap --name first >/dev/null          # first.snapshot

###############################################################################
# 3. Update file to v2, snapshot “second”
###############################################################################
echo 'console.log("v2");' > foo.js
git add foo.js
git commit -m "v2" -q
snap --name second >/dev/null         # second.snapshot (latest)

###############################################################################
# 4. Dirty tree (v3) and run restore tests
###############################################################################
fail=0
ok () { printf '  - %s ✅\n' "$1"; }
ko () { printf '  - %s ❌\n' "$1"; fail=1; }

# helper
do_restore_test () {
  local label="$1" ; shift
  echo 'console.log("v3");' > foo.js      # dirty state
  if "$@" >/dev/null 2>&1; then
    if grep -Fq 'v1' foo.js; then ok "$label"; else ko "$label (content)"; fi
  else
    ko "$label (exit status)"
  fi
}

do_restore_test "restore first (bare)"        snap restore first
do_restore_test "--restore first.snapshot"    snap --restore first.snapshot

###############################################################################
# 5. Final status
###############################################################################
exit "$fail"
