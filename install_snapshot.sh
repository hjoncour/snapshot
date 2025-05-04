#!/usr/bin/env bash
#
# install_snapshot.sh – copy snapshot.sh to ~/bin and create global config
#
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: run inside the snapshot repo." >&2; exit 1; }

src="$repo_root/src/snapshot.sh"
dest_dir="$HOME/bin"
dest="$dest_dir/snapshot"

mkdir -p "$dest_dir"
cp "$src" "$dest"
chmod +x "$dest"
echo "✅ Installed snapshot → $dest"

###############################################################################
# Initialise global config (macOS path)
###############################################################################
cfg_dir="$HOME/Library/Application Support/snapshot"
cfg_file="$cfg_dir/config.json"
mkdir -p "$cfg_dir"

if [ ! -f "$cfg_file" ]; then
  # copy the template shipped with the repo so metadata is present
  cp "$repo_root/config.json" "$cfg_file"
  echo "✅ Created global config → $cfg_file"
else
  echo "ℹ️  Global config already exists → $cfg_file"
fi
