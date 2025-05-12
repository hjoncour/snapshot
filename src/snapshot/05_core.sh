#!/usr/bin/env bash
#
# snapshot/05_core.sh - Core dumping routines + snapshot-to-file
#
set -euo pipefail

# dump_code: outputs code for tracked files matching extensions
dump_code() {
  printf '%s
' "$tracked_files" |
    grep -E -i "$exts" |
    while IFS= read -r f; do
      is_ignored "$f" && continue
      printf '\n===== %s =====\n' "$f"
      cat -- "$f"
    done
}

# filtered_for_tree: lists files for tree view (excluding ignored)
filtered_for_tree() {
  printf '%s
' "$tracked_files" |
    while IFS= read -r f; do
      is_ignored "$f" || printf '%s
' "$f"
    done
}

# save_snapshot: writes dump to
#   $HOME/Library/Application Support/snapshot/<project>/<timestamp>_<branch>_<commit>.snapshot
save_snapshot() {
  # Skip saving if requested
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  # Determine project name: prefer local repo config.json, else global config, else repo directory name
  local local_cfg="$git_root/config.json"
  local proj=""
  if [ -f "$local_cfg" ]; then
    proj=$(jq -r '.project // empty' "$local_cfg" 2>/dev/null || echo "")
  fi
  if [ -z "$proj" ]; then
    proj=$(jq -r '.project // empty' "$global_cfg" 2>/dev/null || echo "")
  fi
  if [ -z "$proj" ]; then
    proj="$(basename "$git_root")"
  fi

  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  out_dir="$cfg_default_dir/$proj"
  mkdir -p "$out_dir"
  out_file="$out_dir/${epoch}_${branch}_${commit}.snapshot"

  cat >"$out_file"
  echo "snapshot: saved dump to $out_file" >&2
  # Output file path for dispatcher
  echo "$out_file"
}
