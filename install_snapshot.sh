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
# 1. Install / overwrite the executable
###############################################################################
mkdir -p "$dest_dir"
bash "$src_dir/make_snapshot.sh" > "$dest"
chmod +x "$dest"
echo "✅ Installed snapshot → $dest"

###############################################################################
# 2. Merge or create the global configuration
###############################################################################
mkdir -p "$cfg_dir"
new_version="$(jq -r '.version' "$template_cfg")"

merge_cfg() {
  jq -s --arg v "$new_version" '
    # helper → if test_paths missing or empty, copy from template
    def ensure_test_paths($tpl):
      if  (.settings.test_paths? // [] | length) == 0
      then .settings.test_paths = $tpl.settings.test_paths
      else .
      end ;

    .[0] as $tpl                       # template (index 0)
  | .[1] as $usr                       # user     (index 1)
  | ($tpl * $usr)                      # user wins on key conflicts
  | ensure_test_paths($tpl)            # inject defaults if needed
  | .version = $v                      # always bump version
  ' "$template_cfg" "$cfg_file" > "$1"
}

if [ -f "$cfg_file" ]; then
  tmp="$(mktemp)"
  merge_cfg "$tmp"
  mv "$tmp" "$cfg_file"
  echo "✅ Updated global config → $cfg_file (version → $new_version)"
else
  cp "$template_cfg" "$cfg_file"
  echo "✅ Created global config → $cfg_file"
fi
