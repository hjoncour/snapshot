#!/usr/bin/env bash
#
# snapshot/05_core.sh – Core dumping routines:
#   • dump_code / filtered_for_tree
#   • save_snapshot
#   • restore_snapshot
#   • archive_snapshots
#   • list_snapshots
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Global safety-net: keep the symbol defined so “set -u” never trips
# ---------------------------------------------------------------------------
filter_tags=()      # will later be shadowed by a local inside list_snapshots

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

  # ── build filename suffix with *bracketed* tag list ──────────────────────
  if ((${#tags[@]})); then
    tag_str=$(IFS=,; echo "[${tags[*]}]")
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
# 3. Restore snapshot                                                         #
###############################################################################
#   snapshot restore            → newest
#   snapshot restore N          → N-th newest (1 = newest)
#   snapshot restore FILE       → exact file (adds .snapshot if missing)
restore_snapshot() {
  requested="${1:-}"

  # ── locate project & directory ──────────────────────────────────────────
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

  # ── pick target file ────────────────────────────────────────────────────
  if [[ -z "$requested" ]]; then
    target="${snaps[0]}"
  elif [[ "$requested" =~ ^[0-9]+$ ]]; then
    idx=$((requested - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#snaps[@]}" ] || {
      echo "snapshot: there is no $requested-latest snapshot." >&2; exit 1; }
    target="${snaps[$idx]}"
  else
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
archive_snapshots() {
  want_name="${1:-}"

  command -v zip >/dev/null 2>&1 || {
    echo "snapshot: 'zip' utility not found in PATH." >&2; exit 1; }

  # ── locate project dir ──────────────────────────────────────────────────
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

  # ── decide archive name ────────────────────────────────────────────────
  if [[ -z "$want_name" ]]; then
    earliest_epoch=$(stat -c "%Y" "${snaps[-1]}" 2>/dev/null || stat -f "%m" "${snaps[-1]}")
    latest_epoch=$(stat -c "%Y" "${snaps[0]}"  2>/dev/null || stat -f "%m" "${snaps[0]}")
    want_name="${earliest_epoch}_${latest_epoch}"
  fi
  [[ "$want_name" == *.zip ]] || want_name="${want_name}.zip"

  (
    cd "$snap_dir"
    zip -qm "$want_name" *.snapshot >/dev/null
  )

  echo "snapshot: archived → $want_name"
}

###############################################################################
# 5. List all snapshots for the current project                              #
###############################################################################
#   snapshot list-snapshots
#   snapshot list-snapshots asc:name
#   snapshot list-snapshots details
#
#   ORDER:  asc|desc:(name|size|date)
list_snapshots() {
  local arg1="${1:-}"
  local want_details=false sort_dir="desc" sort_key="date"
  local -a filter_tags=()      # ALWAYS initialise for nounset safety

  # ── argument parsing ----------------------------------------------------
  if [[ "$arg1" == "tag" ]]; then
    shift
    while (( $# )); do
      case "$1" in
        details|-d)          want_details=true ;;
        asc:*|desc:*)        IFS=':' read -r sort_dir sort_key <<<"$1" ;;
        *)                   filter_tags+=( "$1" ) ;;
      esac
      shift
    done
  else
    case "$arg1" in
      details|-d)          want_details=true; shift ;;
      asc:*|desc:*)        IFS=':' read -r sort_dir sort_key <<<"$arg1"; shift ;;
    esac
  fi

  # ── locate snapshot directory ------------------------------------------
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  shopt -s nullglob
  mapfile -t files < <(ls -1t "$snap_dir"/*.snapshot)
  shopt -u nullglob
  [ ${#files[@]} -gt 0 ] || { echo "snapshot: no snapshot files found." >&2; exit 1; }

  # ── build row list: name|branch|epoch|sizeKB|taglist --------------------
  local -a rows
  for f in "${files[@]}"; do
    base=$(basename "$f" .snapshot)

    if [[ "$base" == *"__["*"]" ]]; then
      tag_part="${base##*__}"
      name_no_tags="${base%%__*}"
    elif [[ "$base" == *"__"* ]]; then
      tag_part="${base##*__}"
      tag_part="${tag_part//_/\,}"
      name_no_tags="${base%%__*}"
    else
      tag_part="-"
      name_no_tags="$base"
    fi

    without_epoch="${name_no_tags#*_}"
    branch="${without_epoch%_*}"
    commit="${without_epoch##*_}"
    [[ "$branch" == "$without_epoch" ]] && commit="-"

    epoch=$(_stat_mtime "$f")
    size_kb=$(_human_kb "$(_stat_size "$f")")

    rows+=( "${name_no_tags}|${branch}|${epoch}|${size_kb}|${tag_part}" )
  done

  # ── optional tag filtering ---------------------------------------------
  if (( ${#filter_tags[@]} )); then
    local -a tmp=()
    for row in "${rows[@]}"; do
      tf="${row##*|}"
      for t in "${filter_tags[@]}"; do
        [[ ",$tf," == *",$t,"* ]] && { tmp+=( "$row" ); break; }
      done
    done
    rows=( "${tmp[@]}" )
  fi

  # ── sort rows -----------------------------------------------------------
  case "$sort_key" in
    name) field=1; num_opt=""   ;;
    size) field=4; num_opt="-n" ;;
    date|*) field=3; num_opt="-n" ;;
  esac
  rev_opt=$([[ $sort_dir == desc ]] && echo "-r" || echo "")
  IFS=$'\n' read -r -d '' -a sorted < <(
    printf '%s\n' "${rows[@]}" |
      sort -t'|' $num_opt $rev_opt -k"$field","$field" -k1,1
    printf '\0'
  )
  unset IFS

  # ── simple list ---------------------------------------------------------
  if ! $want_details; then
    for row in "${sorted[@]}"; do
      echo "${row%%|*}"
    done
    return
  fi

  # ── detailed table ------------------------------------------------------
  local h1="Snapshot" h2="Branch" h3="Date (UTC)" h4="Size" h5="Tags"
  local w1=${#h1} w2=${#h2} w3=${#h3} w4=${#h4} w5=${#h5}

  for row in "${sorted[@]}"; do
    IFS='|' read -r snap branch epoch size tag <<<"$row"
    (( ${#snap}   > w1 )) && w1=${#snap}
    (( ${#branch} > w2 )) && w2=${#branch}
    date_fmt=$(date -u -d "@$epoch" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
               || date -u -r "$epoch" +'%Y-%m-%d %H:%M:%S')
    (( ${#date_fmt} > w3 )) && w3=${#date_fmt}
    size_lbl="${size} KB"
    (( ${#size_lbl} > w4 )) && w4=${#size_lbl}
    (( ${#tag} > w5 )) && w5=${#tag}
  done

  sep=" | "
  printf "%-${w1}s${sep}%-${w2}s${sep}%-${w3}s${sep}%${w4}s${sep}%-${w5}s\n" \
         "$h1" "$h2" "$h3" "$h4" "$h5"
  printf "%-${w1}s${sep}%-${w2}s${sep}%-${w3}s${sep}%${w4}s${sep}%-${w5}s\n" \
         "$(printf '%*s' "$w1" '' | tr ' ' '-')" \
         "$(printf '%*s' "$w2" '' | tr ' ' '-')" \
         "$(printf '%*s' "$w3" '' | tr ' ' '-')" \
         "$(printf '%*s' "$w4" '' | tr ' ' '-')" \
         "$(printf '%*s' "$w5" '' | tr ' ' '-')"

  for row in "${sorted[@]}"; do
    IFS='|' read -r snap branch epoch size tag <<<"$row"
    date_fmt=$(date -u -d "@$epoch" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
               || date -u -r "$epoch" +'%Y-%m-%d %H:%M:%S')
    printf "%-${w1}s${sep}%-${w2}s${sep}%-${w3}s${sep}%${w4}s${sep}%-${w5}s\n" \
           "$snap" "$branch" "$date_fmt" "${size} KB" "$tag"
  done
}
