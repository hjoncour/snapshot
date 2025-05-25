#!/usr/bin/env bash
#
# snapshot/05_core.sh – Core dumping routines:
#   • dump_code / filtered_for_tree
#   • save_snapshot
#   • restore_snapshot   (latest, N-th latest, or explicit filename)
#   • archive_snapshots
#
set -euo pipefail

###############################################################################
# 1. Dump helpers                                                             #
###############################################################################

dump_code() {
  printf '%s\n' "$tracked_files" |
    grep -E -i "$exts" |
    while IFS= read -r f; do
      is_ignored "$f" && continue
      printf '\n===== %s =====\n' "$f"
      cat -- "$f"
    done
}

filtered_for_tree() {
  printf '%s\n' "$tracked_files" |
    while IFS= read -r f; do
      is_ignored "$f" || printf '%s\n' "$f"
    done
}

###############################################################################
# 2. Save a snapshot dump to disk                                             #
###############################################################################
save_snapshot() {
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  tmp=$(mktemp)
  cat >"$tmp"

  if ((${#tags[@]})); then
    tag_str=$(IFS=_; echo "${tags[*]}")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

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

  if ((${#dest_dirs[@]})); then
    dests=("${dest_dirs[@]}")
  else
    local_cfg="$git_root/config.json"
    proj=""
    if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
    [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
    [ -z "$proj" ] && proj=$(basename "$git_root")
    dests=( "$cfg_default_dir/$proj" )
  fi

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
  printf '%s\n' "${results[@]}"
}

###############################################################################
# 3. Restore snapshot (latest, specific file, or by index)                    #
###############################################################################
# Usage:
#   snapshot restore            → newest snapshot for project
#   snapshot restore FILE       → FILE (with or without .snapshot)
#   snapshot restore N          → N-th newest (1 = newest)
#
restore_snapshot() {
  requested="${1:-}"        # empty = newest

  # ── find project & snapshot dir ──────────────────────────────────────────
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  # ── choose snapshot file ────────────────────────────────────────────────
  if [[ -z "$requested" ]]; then
    target=$(ls -1t "$snap_dir"/*.snapshot 2>/dev/null | head -n1)
  elif [[ "$requested" =~ ^[0-9]+$ ]]; then
    # numeric index ⇒ N-th newest, 1-based
    idx="$requested"
    target=$(ls -1t "$snap_dir"/*.snapshot 2>/dev/null | sed -n "${idx}p")
  else
    [[ "$requested" == *.snapshot ]] || requested="${requested}.snapshot"
    if [[ "$requested" == */* && -f "$requested" ]]; then
      target="$requested"
    else
      target="$snap_dir/$requested"
    fi
  fi

  [ -n "${target:-}" ] && [ -f "$target" ] || {
    echo "snapshot: '${requested:-latest}' not found in $snap_dir." >&2; exit 1; }

  echo "snapshot: restoring from $(basename "$target")"

  # ── replay dump into working tree ───────────────────────────────────────
  current_file=""
  pending_blank=false

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^=====[[:space:]](.+)[[:space:]]===== ]]; then
      current_file="${BASH_REMATCH[1]}"
      mkdir -p "$(dirname "$git_root/$current_file")"
      : > "$git_root/$current_file"
      pending_blank=false
      continue
    fi

    if [[ -z "$line" ]]; then
      pending_blank=true
      continue
    fi
    if $pending_blank; then
      printf '\n' >> "$git_root/$current_file"
      pending_blank=false
    fi

    [[ -n "$current_file" ]] && printf '%s\n' "$line" >> "$git_root/$current_file"
  done < "$target"

  echo "snapshot: restore complete."
}

###############################################################################
# 4. Archive snapshots into a zip (new command)                               #
###############################################################################
# Usage:
#   snapshot archive            → auto-named  <earliest>_<latest>.zip
#   snapshot archive NAME.zip   → custom name ('.zip' optional)
#
archive_snapshots() {
  custom="${1:-}"

  # locate project / dir
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  mapfile -t snaps < <(ls -1t "$snap_dir"/*.snapshot 2>/dev/null || true)
  [ "${#snaps[@]}" -gt 0 ] || { echo "snapshot: nothing to archive." >&2; exit 1; }

  earliest_file="${snaps[-1]}"
  latest_file="${snaps[0]}"

  e_epoch=$(stat -f "%m" "$earliest_file" 2>/dev/null || stat -c "%Y" "$earliest_file")
  l_epoch=$(stat -f "%m" "$latest_file"   2>/dev/null || stat -c "%Y" "$latest_file")

  if [[ -z "$custom" ]]; then
    base="${e_epoch}_${l_epoch}"
  else
    base="$custom"
  fi
  [[ "$base" == *.zip ]] || base="${base}.zip"
  dest="$git_root/$base"

  command -v zip >/dev/null 2>&1 || {
    echo "snapshot: 'zip' command not found in PATH." >&2; exit 1; }

  zip -q -j "$dest" "$snap_dir"/*.snapshot
  count=${#snaps[@]}
  echo "snapshot: archived $count file(s) → $(basename "$dest")"
}
