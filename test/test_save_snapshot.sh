#!/usr/bin/env bash
#
# Validate automatic dump saving and --no-snapshot override.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
mkdir -p "$HOME"

cd "$tmpdir"
git init -q
echo "console.log('hi');" > foo.js
echo '{}' > config.json
git add . >/dev/null

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

# global config with project name
cat > global.json <<'EOF'
{ "project":"demo" }
EOF

###############################################################################
# 1. run without flag → file must appear
###############################################################################
snap >/dev/null
saved_dir="$HOME/Library/Application Support/snapshot/demo"
files=("$saved_dir"/*)
[ "${#files[@]}" -eq 1 ] || { echo "❌ expected one saved dump"; exit 1; }

###############################################################################
# 2. run with --no-snapshot → no new file
###############################################################################
snap --no-snapshot >/dev/null
files2=("$saved_dir"/*)
[ "${#files2[@]}" -eq 1 ] || { echo "❌ --no-snapshot still saved a file"; exit 1; }

echo "✅ snapshot saving & --no-snapshot work"
