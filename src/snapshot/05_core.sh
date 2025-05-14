#!/usr/bin/env bash
#
# snapshot/05_core.sh - Core dumping routines + snapshot-to-file
#
set -euo pipefail

# dump_code: outputs code for tracked files matching extensions
dump_code() {
  printf '%s\n' "$tracked_files" |
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
#   $HOME/Library/Application Support/snapshot/<project>/<name>.snapshot or
#   $HOME/Library/Application Support/snapshot/<project>/<timestamp>_<branch>_<commit>.snapshot
#!/usr/bin/env bash
#
# snapshot/05_core.sh - Core dumping routines + snapshot-to-file
#
save_snapshot() {
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  local tmp; tmp=$(mktemp)
  cat >"$tmp"

  # project/name/timestamp logic unchanged…
  local local_cfg proj epoch branch commit out_dir out_file
  local_cfg="$git_root/config.json"
  if [ -f "$local_cfg" ]; then
    proj=$(jq -r '.project // empty' "$local_cfg" 2>/dev/null)
  fi
  if [ -z "${proj:-}" ]; then
    proj=$(jq -r '.project // empty' "$global_cfg" 2>/dev/null)
  fi
  [ -n "${proj:-}" ] || proj="$(basename "$git_root")"

  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  out_dir="$cfg_default_dir/$proj"
  mkdir -p "$out_dir"

  # write one file per custom name, or a single timestamped file
  if [ "${#custom_names[@]}" -gt 0 ]; then
    for name in "${custom_names[@]}"; do
      out_file="$out_dir/${name}.snapshot"
      cp "$tmp" "$out_file"
      echo "snapshot: saved dump to $out_file" >&2
    done
  else
    out_file="$out_dir/${epoch}_${branch}_${commit}.snapshot"
    mv "$tmp" "$out_file"
    echo "snapshot: saved dump to $out_file" >&2
  fi

  rm -f "$tmp"
}
