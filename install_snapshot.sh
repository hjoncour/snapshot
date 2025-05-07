#!/usr/bin/env bash
#
# install_snapshot.sh – copy snapshot.sh to ~/bin and create / update global
#                       configuration in “~/Library/Application Support/snapshot”
#
set -euo pipefail

###############################################################################
# Ensure we’re running under Bash (users often type “sh install_snapshot.sh”).
###############################################################################
if [ -z "${BASH_VERSION:-}" ]; then
  echo "⚠️  Please run this installer with Bash:"
  echo "   ./install_snapshot.sh     # or: bash install_snapshot.sh"
  exit 2
fi

###############################################################################
# 0. Locate the repo & important paths
###############################################################################
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: run the installer from inside the snapshot repo." >&2; exit 1; }

src="$repo_root/src/snapshot.sh"
dest_dir="$HOME/bin"
dest="$dest_dir/snapshot"

cfg_dir="$HOME/Library/Application Support/snapshot"
cfg_file="$cfg_dir/config.json"
template_cfg="$repo_root/config.json"   # ships with the repo

###############################################################################
# 1. Install the executable
###############################################################################
mkdir -p "$dest_dir"
cp "$src" "$dest"
chmod +x "$dest"
echo "✅ Installed snapshot → $dest"

###############################################################################
# 2. (Re‑)initialise the global configuration
###############################################################################
mkdir -p "$cfg_dir"

if [ ! -f "$template_cfg" ]; then
  echo "Error: template config.json not found in repo root." >&2
  exit 1
fi

if [ -f "$cfg_file" ]; then
  # Merge user config with the template so we never lose existing keys.
  tmp="$(mktemp)"
  jq -s '.[0] * .[1]' "$template_cfg" "$cfg_file" > "$tmp"
  mv "$tmp" "$cfg_file"
  echo "✅ Updated global config → $cfg_file"
else
  cp "$template_cfg" "$cfg_file"
  echo "✅ Created global config → $cfg_file"
fi
