#!/usr/bin/env bash
#
# snapshot/core/list.sh – list_snapshots
#
set -euo pipefail

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
