#!/usr/bin/env bash
#
# Validate snapshot --tag support:
#   1) single file + multiple tags
#   2) multiple files + multiple tags
#   3) multiple files + tags + --print + --copy   (with debug logging)
#
set -euo pipefail

###############################################################################
# 0. Locate repo root (for make_snapshot.sh)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Collect temp dirs for cleanup
###############################################################################
TMP_DIRS=()
cleanup() { for d in "${TMP_DIRS[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

###############################################################################
# 2. Helper to create isolated repo + “snap” wrapper
###############################################################################
setup_repo() {
  tmpdir=$(mktemp -d)
  TMP_DIRS+=("$tmpdir")
  cd "$tmpdir"

  git init -q
  echo "console.log('tag');" > tag.js
  echo '{}' > config.json
  git add . >/dev/null

  mkdir -p src
  bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
  chmod +x src/snapshot.sh

  snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }
}

###############################################################################
# 3-A. Single file, two tags
###############################################################################
setup_repo
cat > global.json <<'EOF'
{ "project":"demo" }
EOF

echo "→ single file, two tags"
snap --name one --tag t1 t2 >/dev/null
expected="$HOME/Library/Application Support/snapshot/demo/one__[t1,t2].snapshot"
[ -f "$expected" ] || { echo "❌ expected $expected"; exit 1; }
echo "✅ single file, two tags"

###############################################################################
# 3-B. Multiple files, two tags
###############################################################################
setup_repo
cat > global.json <<'EOF'
{ "project":"demo" }
EOF

echo "→ multiple files, two tags"
snap --name a b --tag x y >/dev/null
for n in a b; do
  f="$HOME/Library/Application Support/snapshot/demo/${n}__[x,y].snapshot"
  [ -f "$f" ] || { echo "❌ expected $f"; exit 1; }
done
echo "✅ multiple files, two tags"

###############################################################################
# 3-C. Multiple files + tags + --print + --copy  (debug)
###############################################################################
setup_repo
cat > global.json <<'EOF'
{ "project":"demo" }
EOF

echo "→ multiple files + tags + --print + --copy"
output=$(snap --name c d --tag z w --print --copy)

###############################################################################
# Debug logs – show command output and clipboard (if available)
###############################################################################
echo "──── begin captured output ────"
printf '%s\n' "$output"
echo "──── end captured output ─────"

if command -v pbpaste >/dev/null 2>&1; then
  echo "──── clipboard (first 10 lines) ────"
  pbpaste | head -n 10
  echo "──── end clipboard ────"
else
  echo "(pbpaste not available – clipboard check skipped)"
fi

###############################################################################
# Verify printed dump header
###############################################################################
echo "$output" | grep -q "^===== tag.js =====" || {
  echo "❌ printed dump header missing"
  exit 1
}

###############################################################################
# Verify copy confirmation (allow graceful skip if pbcopy missing)
# NOTE: allow *any* whitespace before the byte count.
###############################################################################
if ! echo "$output" | grep -Eq "snapshot: copied[[:space:]]+[0-9]+ bytes to clipboard\."; then
  if echo "$output" | grep -q "install 'pbcopy' first."; then
    echo "(pbcopy unavailable – confirmation skipped)"
  else
    echo "❌ copy confirmation missing"
    exit 1
  fi
fi

###############################################################################
# Verify snapshot files exist
###############################################################################
for n in c d; do
  p="$HOME/Library/Application Support/snapshot/demo/${n}__[z,w].snapshot"
  [ -f "$p" ] || { echo "❌ missing $p"; exit 1; }
done
echo "✅ multiple files, tags, with --print and --copy"
