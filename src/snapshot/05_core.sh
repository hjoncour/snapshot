#!/usr/bin/env bash
#
# snapshot/05_core.sh – Core dumping routines:
#   • dump_code / filtered_for_tree
#   • save_snapshot
#   • restore_snapshot
#   • archive_snapshots   ← NEW
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
# 2.  Save a snapshot dump to disk                                            #
###############################################################################
save_snapshot() {
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  tmp=$(mktemp)
  cat >"$tmp"

  # ── build filename suffix with *bracketed* tag list ──────────────────────
  if ((${#tags[@]})); then
    tag_str=$(IFS=,; echo "[${tags[*]}]")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}                       # keep filenames FS-friendly
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  base_names=()
  if ((${#custom_names[@]})); then
    for n in "${custom_names[@]}"; do
      base_names+=( "${n}${suffix}.snapshot" )
    done
  else
    base_names+=( "${epoch}_${branch}_${commit}${suffix}.snapshot" )
  fi

  # ── destination directory/directories determination ─────────────────────
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

  # ── write snapshot(s) ────────────────────────────────────────────────────
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
# 3. Restore snapshot (latest, nth-latest, or specific file)                  #
###############################################################################
# Usage:
#   snapshot restore                   → newest snapshot for project
#   snapshot restore N                 → N-th newest (1 = newest)
#   snapshot restore FILE              → restore FILE (adds .snapshot if missing)
#
restore_snapshot() {
  requested="${1:-}"     # empty / number / filename

  # ── determine project name & snapshot dir ───────────────────────────────
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  shopt -s nullglob
  mapfile -t snaps < <(ls -1t "$snap_dir"/*.snapshot 2>/dev/null)
  shopt -u nullglob
  [ "${#snaps[@]}" -gt 0 ] || { echo "snapshot: no snapshot files in $snap_dir." >&2; exit 1; }

  # ── choose snapshot file ────────────────────────────────────────────────
  if [[ -z "$requested" ]]; then
    target="${snaps[0]}"
  elif [[ "$requested" =~ ^[0-9]+$ ]]; then            # numeric index
    idx=$((requested - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#snaps[@]}" ] || {
      echo "snapshot: there is no $requested-latest snapshot." >&2; exit 1; }
    target="${snaps[$idx]}"
  else                                                 # explicit filename
    [[ "$requested" == *.snapshot ]] || requested="${requested}.snapshot"
    if [[ "$requested" == */* && -f "$requested" ]]; then
      target="$requested"
    else
      target="$snap_dir/$requested"
    fi
    [ -f "$target" ] || { echo "snapshot: '$requested' not found in $snap_dir." >&2; exit 1; }
  fi

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
# 4. Archive all snapshots for the project                                   #
###############################################################################
# Usage:
#   snapshot archive [ARCHIVE_NAME]
#   • Creates   <snap_dir>/<ARCHIVE_NAME>.zip
#   • If no name given →  <earliestEpoch>_<latestEpoch>.zip
#   • Moves (-m) ⇒ source .snapshot files are deleted after zipping
#
archive_snapshots() {
  want_name="${1:-}"

  command -v zip >/dev/null 2>&1 || {
    echo "snapshot: 'zip' utility not found in PATH." >&2; exit 1; }

  # ── determine project & directory ───────────────────────────────────────
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  shopt -s nullglob
  mapfile -t snaps < <(ls -1 "$snap_dir"/*.snapshot 2>/dev/null)
  shopt -u nullglob
  [ "${#snaps[@]}" -gt 0 ] || { echo "snapshot: no snapshot files to archive." >&2; exit 1; }

  # ── determine archive name ──────────────────────────────────────────────
  if [[ -z "$want_name" ]]; then
    earliest_epoch=$(stat -f "%m" "${snaps[0]}" 2>/dev/null \
                     || stat -c "%Y" "${snaps[0]}")
    latest_epoch=$(stat -f "%m" "${snaps[-1]}" 2>/dev/null \
                   || stat -c "%Y" "${snaps[-1]}")
    want_name="${earliest_epoch}_${latest_epoch}"
  fi
  [[ "$want_name" == *.zip ]] || want_name="${want_name}.zip"

  out="$snap_dir/$want_name"
  (
    cd "$snap_dir"
    zip -qm "$out" *.snapshot >/dev/null
  )

  echo "snapshot: archived → $(basename "$out")"
}

###############################################################################
# 5.  List all snapshots for the current project                              #
###############################################################################
# Usage:
#   snapshot --list                → simple list (latest first)
#   snapshot --list asc:name       → ordered output
#   snapshot --list details        → pretty table
#   snapshot --list -d             → shorthand for details
#
#   ORDER arg:  asc|desc:(name|size|date)
#
list_snapshots() {
  local arg1="${1:-}"                 # may be order or 'details' / -d
  local want_details=false
  local sort_dir="desc"               # default = newest first
  local sort_key="date"

  case "$arg1" in
    details|-d) want_details=true ;;
    asc:*|desc:*)
        IFS=':' read -r sort_dir sort_key <<<"$arg1" ;;
    "" ) ;;                           # no options
    * ) echo "snapshot: unknown --list option '$arg1'." >&2; exit 2 ;;
  esac

  # ── resolve project → snapshot directory ────────────────────────────────
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  shopt -s nullglob
  mapfile -t files < <(ls -1 "$snap_dir"/*.snapshot 2>/dev/null)
  shopt -u nullglob
  [ "${#files[@]}" -gt 0 ] || { echo "snapshot: no snapshot files found." >&2; exit 1; }

  # ── collect meta rows: name|size|epoch|branch|tagStr ────────────────────
  rows=()
  for f in "${files[@]}"; do
    base=$(basename "$f" .snapshot)

    # split off optional tag suffix “__[…]" first
    if [[ "$base" == *"__["*"]" ]]; then
      tag_part="${base##*__}"
      tag_part="${tag_part#[}" ; tag_part="${tag_part%]}"
      name_no_tags="${base%%__*}"
    else
      tag_part="-"
      name_no_tags="$base"
    fi

    # remove leading epoch_  → branch_commit  split on last “_”
    without_epoch="${name_no_tags#*_}"
    branch="${without_epoch%_*}"
    commit="${without_epoch##*_}"
    # If there was no “_” after the epoch -> treat whole part as branch
    if [[ "$branch" == "$without_epoch" ]]; then
      branch="$without_epoch"
      commit="-"
    fi

    epoch=$(_stat_mtime "$f")
    size_bytes=$(_stat_size "$f")
    size_kb=$(_human_kb "$size_bytes")

    rows+=( "${base}|${size_kb}|${epoch}|${branch}|${tag_part}" )
  done

  # ── sorting ─────────────────────────────────────────────────────────────
  case "$sort_key" in
    name) field=1; num="";;
    size) field=2; num="-n";;
    date) field=3; num="-n";;
    *)    field=3; num="-n";;
  esac
  [[ "$sort_dir" == desc ]] && rev="-r" || rev=""

  sorted=$(printf '%s\n' "${rows[@]}" |
           sort -t'|' $num $rev -k"$field","$field")

  if ! $want_details; then
    # simple mode – filenames only
    printf '%s\n' "$sorted" | cut -d'|' -f1
    return
  fi

  # ── details table – compute dynamic widths ─────────────────────────────
  header_name="Snapshot"
  header_branch="Branch"
  header_date="Date (UTC)"
  header_size="KB"
  header_tags="Tags"

  max_name=${#header_name}
  max_branch=${#header_branch}
  max_date=${#header_date}
  max_size=${#header_size}

  while IFS='|' read -r n sz _e br _t; do
    (( ${#n}  > max_name   )) && max_name=${#n}
    (( ${#br} > max_branch )) && max_branch=${#br}
    (( ${#sz} > max_size   )) && max_size=${#sz}
  done <<<"$sorted"

  dash() { printf '%*s' "$1" '' | tr ' ' '-'; }

  printf "%-${max_name}s | %-${max_branch}s | %-${max_date}s | %${max_size}s | %s\n" \
         "$header_name" "$header_branch" "$header_date" "$header_size" "$header_tags"
  printf "%-${max_name}s | %-${max_branch}s | %-${max_date}s | %${max_size}s | %s\n" \
         "$(dash "$max_name")" "$(dash "$max_branch")" "$(dash "$max_date")" \
         "$(dash "$max_size")" "$(dash ${#header_tags})"

  while IFS='|' read -r n sz epo br tg; do
    date_fmt=$(date -u -d "@$epo" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
               || date -u -r "$epo" +'%Y-%m-%d %H:%M:%S')
    printf "%-${max_name}s | %-${max_branch}s | %-${max_date}s | %${max_size}s | %s\n" \
           "$n" "$br" "$date_fmt" "$sz" "$tg"
  done <<<"$sorted"
}
