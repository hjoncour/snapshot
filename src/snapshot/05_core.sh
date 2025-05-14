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
  printf '%s\n' "$tracked_files" |
    while IFS= read -r f; do
      is_ignored "$f" || printf '%s\n' "$f"
    done
}

# save_snapshot: writes dump to
#   $HOME/Library/Application Support/snapshot/<project>/<name>.snapshot
save_snapshot() {
  # Skip saving if requested
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  # slurp the entire dump into a temp file
  local tmp
  tmp=$(mktemp)
  cat >"$tmp"

  # build a “__tag1_tag2” suffix if any tags were passed
  if [ "${#tags[@]}" -gt 0 ]; then
    tag_str=$(IFS=_; echo "${tags[*]}")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

  # figure out project name
  local local_cfg proj
  local_cfg="$git_root/config.json"
  if [ -f "$local_cfg" ]; then
    proj=$(jq -r '.project // empty' "$local_cfg" 2>/dev/null || echo "")
  fi
  if [ -z "${proj:-}" ]; then
    proj=$(jq -r '.project // empty' "$global_cfg" 2>/dev/null || echo "")
  fi
  [ -n "${proj:-}" ] || proj="$(basename "$git_root")"

  # git metadata for fallback timestamped filenames
  local epoch branch commit out_dir out_file results
  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  out_dir="$cfg_default_dir/$proj"
  mkdir -p "$out_dir"

  results=()
  if [ "${#custom_names[@]}" -gt 0 ]; then
    for name in "${custom_names[@]}"; do
      out_file="$out_dir/${name}${suffix}.snapshot"
      cp "$tmp" "$out_file"
      echo "snapshot: saved dump to $out_file" >&2
      results+=("$out_file")
    done
  else
    out_file="$out_dir/${epoch}_${branch}_${commit}.snapshot"
    mv "$tmp" "$out_file"
    echo "snapshot: saved dump to $out_file" >&2
    results+=("$out_file")
  fi

  rm -f "$tmp"

  # emit the list of files for downstream use
  printf '%s\n' "${results[@]}"
}
