#!/usr/bin/env bash
#
# Validate automatic dump saving and --no-snapshot override.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

###########################################################################
# 0. Isolated HOME and repo initialisation
###########################################################################
export HOME="$tmpdir/home"
mkdir -p "$HOME"
cd "$tmpdir"
git init -q

# ── sample file and *repo-local* config.json with project name ────────────
echo "console.log('hi');" > foo.js
cat > config.json <<'EOF'
{ "project": "demo" }
EOF
git add . >/dev/null

###########################################################################
# 1. Build one-file snapshot stub
###########################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# Helper to invoke snapshot with an isolated global config
snap() {
  SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"
}

# Minimal global config (project key is no longer required here)
echo '{}' > "$tmpdir/global.json"

saved_dir="$HOME/Library/Application Support/snapshot/demo"

###########################################################################
# 2. Run without flags → exactly one file must be created
###########################################################################
snap >/dev/null
files=("$saved_dir"/*)
[ "${#files[@]}" -eq 1 ] || { echo "❌ expected one saved dump"; exit 1; }

###########################################################################
# 3. Run with --no-snapshot → no additional file must appear
###########################################################################
snap --no-snapshot >/dev/null
files_after=("$saved_dir"/*)
[ "${#files_after[@]}" -eq 1 ] || { echo "❌ --no-snapshot still saved a file"; exit 1; }

echo "✅ snapshot saving & --no-snapshot work"
