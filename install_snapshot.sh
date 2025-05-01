#!/usr/bin/env bash
#
# install_snapshot.sh — copy this repo’s snapshot.sh into ~/bin/snapshot
#

set -euo pipefail

# 1. find this repo’s root
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: must run inside a Git repository." >&2
  exit 1
}

src="$repo_root/src/snapshot.sh"
dest_dir="$HOME/bin"
dest="$dest_dir/snapshot"

# 2. ensure source exists
if [ ! -f "$src" ]; then
  echo "Error: $src not found." >&2
  exit 2
fi

# 3. create target dir & copy
mkdir -p "$dest_dir"
cp "$src" "$dest"
chmod +x "$dest"

echo "✅ Installed snapshot → $dest"
