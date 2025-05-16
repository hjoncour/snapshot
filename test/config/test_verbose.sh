#!/usr/bin/env bash
#
# test_verbose.sh – verify:
#   • per-call  --verbose:LEVEL
#   • persisted set-verbose:LEVEL
#
set -euo pipefail

# locate repo root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

# isolated HOME + repo
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
mkdir -p "$HOME"

cd "$tmpdir"
git init -q
echo "console.log('hello');" > foo.js
echo '{}' > config.json
git add . >/dev/null

# build snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

echo '{}' > global.json      # fresh global config

fail=0
ok () { printf '  - %s ✅\n' "$1"; }
ko () { printf '  - %s ❌\n' "$1"; fail=1; }

###############################################################################
# 1. minimal  ── “[name].snapshot created”
###############################################################################
out=$(snap --name alpha --verbose:minimal 2>/dev/null)
[[ "$out" == "[alpha.snapshot] created" ]] && ok "minimal message" || ko "minimal message"

###############################################################################
# 2. mute     ── absolutely no STDOUT
###############################################################################
out=$(snap --name beta --verbose:mute 2>/dev/null || true)
[[ -z "$out" ]] && ok "mute message" || ko "mute message"

###############################################################################
# 3. verbose  ── header + row table
###############################################################################
out=$(snap --name charlie --verbose:verbose 2>/dev/null)
hdr=$(grep -c "^Snapshot" <<<"$out" || true)
row=$(grep -c "charlie.snapshot" <<<"$out" || true)
[[ $hdr -eq 1 && $row -eq 1 ]] && ok "verbose table" || ko "verbose table"

###############################################################################
# 4. set-verbose persists (“mute”)
###############################################################################
snap set-verbose:mute >/dev/null
jq -e '.settings.preferences.verbose=="mute"' global.json >/dev/null && \
  ok "set-verbose updated config" || ko "set-verbose updated config"

out=$(snap --name delta 2>/dev/null || true)
[[ -z "$out" ]] && ok "persisted mute" || ko "persisted mute"

###############################################################################
exit "$fail"
