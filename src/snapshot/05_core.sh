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

# save_snapshot: writes dump either to the usual support dir (default)
#                or to the user-supplied --to paths.
#   Supports multiple --name values, multiple --tag values,
#   and multiple --to destinations.
save_snapshot() {
  # honour --no-snapshot
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  # read whole dump into a temp file
  tmp=$(mktemp)
  cat >"$tmp"

  # prepare “__tag1_tag2” suffix (or empty)
  if ((${#tags[@]})); then
    tag_str=$(IFS=_; echo "${tags[*]}")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

  ###########################################################################
  # a) determine the *base* filename(s) (with or without --name …)
  ###########################################################################
  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  base_names=()
  if ((${#custom_names[@]})); then
    for n in "${custom_names[@]}"; do
      base_names+=( "${n}${suffix}.snapshot" )
    done
  else
    base_names+=( "${epoch}_${branch}_${commit}${suffix}.snapshot" )
  fi

  ###########################################################################
  # b) determine *destination directories*
  ###########################################################################
  if ((${#dest_dirs[@]})); then
    dests=("${dest_dirs[@]}")
  else
    # default support dir: ~/Library/Application Support/snapshot/<project>
    local_cfg="$git_root/config.json"
    proj=""
    if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
    [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
    [ -z "$proj" ] && proj=$(basename "$git_root")
    dests=( "$cfg_default_dir/$proj" )
  fi

  ###########################################################################
  # c) write out every <dest>/<basename>; report each path
  ###########################################################################
  results=()
  for d in "${dests[@]}"; do
    mkdir -p "$d"
    for b in "${base_names[@]}"; do
      out="$d/$b"
      cp "$tmp" "$out"
      echo "snapshot: saved dump to $out" >&2
      results+=( "$out" )
    done
  done

  rm -f "$tmp"

  # emit list (newline-separated) for callers (print|copy dispatchers)
  printf '%s\n' "${results[@]}"
}
