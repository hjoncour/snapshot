#!/usr/bin/env bash
#
# install_snapshot.sh – copy snapshot to ~/bin and create / update the
# global configuration in “~/Library/Application Support/snapshot”.
#
set -euo pipefail

###############################################################################
# Ensure we’re running under Bash (users often type “sh install_snapshot.sh”)
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

src_dir="$repo_root/src"
dest_dir="$HOME/bin"
dest="$dest_dir/snapshot"

cfg_dir="$HOME/Library/Application Support/snapshot"
cfg_file="$cfg_dir/config.json"
template_cfg="$repo_root/config.json"

###############################################################################
# 1. Install/overwrite the executable
###############################################################################
mkdir -p "$dest_dir"
bash "$src_dir/make_snapshot.sh" > "$dest"
chmod +x "$dest"
echo "✅ Installed snapshot → $dest"

###############################################################################
# 2. (Re-)initialise / merge the global configuration
###############################################################################
mkdir -p "$cfg_dir"

if [ ! -f "$template_cfg" ]; then
  echo "Error: template config.json not found." >&2
  exit 1
fi

# Always grab the version that ships with the repo being installed
new_version="$(jq -r '.version' "$template_cfg")"

if [ -f "$cfg_file" ]; then
  tmp="$(mktemp)"

  # Merge user config (.[1]) on top of template (.[0]) *then*
  # force-set the version field to the new repo version so the
  # user’s file is updated whenever they install a newer release.
  jq -s --arg v "$new_version" '
        (.[0] * .[1])          # keep all keys, give precedence to user file
        | .version = $v        # …but override the version with the latest
      ' "$template_cfg" "$cfg_file" > "$tmp"

  mv "$tmp" "$cfg_file"
  echo "✅ Updated global config → $cfg_file (version → $new_version)"
else
  # First-time install → just copy the template straight over
  cp "$template_cfg" "$cfg_file"
  echo "✅ Created global config → $cfg_file"
fi
