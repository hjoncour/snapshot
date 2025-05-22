#!/usr/bin/env bash
#
# snapshot/05_core.sh – Core dumping routines:
#   • dump_code / filtered_for_tree
#   • save_snapshot
#   • restore_snapshot
#
set -euo pipefail

###############################################################################
# 1. Dump helpers                                                             #
###############################################################################

# dump_code: output code for every tracked file whose extension matches the
#            configured (or default) list, skipping any ignored paths/files.
dump_code() {
  printf '%s\n' "$tracked_files" |
    grep -E -i "$exts" |
    while IFS= read -r f; do
      is_ignored "$f" && continue
      printf '\n===== %s =====\n' "$f"
      cat -- "$f"
    done
}

# filtered_for_tree: like dump_code’s first pass, but emits only file paths;
#                    useful for the --tree command.
filtered_for_tree() {
  printf '%s\n' "$tracked_files" |
    while IFS= read -r f; do
      is_ignored "$f" || printf '%s\n' "$f"
    done
}

###############################################################################
# 2. Save a snapshot dump to disk                                             #
###############################################################################
# save_snapshot reads a complete dump from STDIN and writes it to one or
# several .snapshot files, depending on --name, --tag and --to arguments.
# It echoes the resulting file paths (newline-separated) so callers can react
# (e.g. print a success table or copy/print the dump).
save_snapshot() {
  # honour --no-snapshot
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  # read whole dump into a temp file
  tmp=$(mktemp)
  cat >"$tmp"

  # build optional “__tag1_tag2” suffix
  if ((${#tags[@]})); then
    tag_str=$(IFS=_; echo "${tags[*]}")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

  ###########################################################################
  # a) base filename(s)
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
  # b) destination directories
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
  # c) copy file(s) & optionally announce
  ###########################################################################
  results=()
  for d in "${dests[@]}"; do
    mkdir -p "$d"
    for b in "${base_names[@]}"; do
      out="$d/$b"
      cp "$tmp" "$out"
      results+=( "$out" )
    done
  done

  rm -f "$tmp"

  # emit list (newline-separated) for callers (print|copy dispatchers)
  printf '%s\n' "${results[@]}"
}

###############################################################################
# 3. Restore the latest snapshot                                              #
###############################################################################
# restore_snapshot: locate the newest .snapshot file for this project and
#                   recreate every file in the working tree exactly as saved.
#
# ‣ The project name is taken in priority from repo-local config.json,
#   then global config, then the current directory’s basename.
# ‣ All folders are auto-created. Existing files are overwritten.
# ‣ Outputs a short progress message.
restore_snapshot() {
  ###########################################################################
  # 0. Locate the snapshot directory and newest file for this project
  ###########################################################################
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || {
    echo "snapshot: no snapshots found for project '$proj'." >&2; exit 1; }

  latest=$(ls -1t "$snap_dir"/*.snapshot 2>/dev/null | head -n1)
  [ -n "$latest" ] || {
    echo "snapshot: no snapshot files in $snap_dir." >&2; exit 1; }

  echo "snapshot: restoring from $(basename "$latest")"

  ###########################################################################
  # 1. Parse the dump and recreate every file
  ###########################################################################
  current_file=""
  while IFS= read -r line || [ -n "$line" ]; do
    # ── New header?  → start (or switch) target file ──────────────────────
    if [[ "$line" =~ ^=====[[:space:]](.+)[[:space:]]===== ]]; then
      current_file="${BASH_REMATCH[1]}"
      mkdir -p "$(dirname "$git_root/$current_file")"
      : > "$git_root/$current_file"      # create / truncate
      continue
    fi

    # ── Normal content line ── append only if a header has been seen ──────
    [[ -n "$current_file" ]] && printf '%s\n' "$line" >> "$git_root/$current_file"
  done < "$latest"

  echo "snapshot: restore complete."
}
