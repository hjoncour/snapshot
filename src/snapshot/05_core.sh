#!/usr/bin/env bash
#
# snapshot/05_core.sh – Core dumping routines:
#   • dump_code / filtered_for_tree
#   • save_snapshot
#   • restore_snapshot   (latest, N-th latest, or explicit filename)
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
# 3. Restore snapshot (newest, N-th newest, or explicit file)                 #
###############################################################################
# Usage examples:
#   snapshot restore            → newest snapshot
#   snapshot restore 1          → newest snapshot (same as above)
#   snapshot restore 3          → 3rd newest snapshot
#   snapshot restore NAME       → restore NAME[.snapshot]
#
restore_snapshot() {
  requested="${1:-}"   # empty → newest | number → N-th newest | filename

  # ── determine project + snapshot directory ──────────────────────────────
  local_cfg="$git_root/config.json"
  proj=""
  if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
  [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$proj" ] && proj=$(basename "$git_root")

  snap_dir="$cfg_default_dir/$proj"
  [ -d "$snap_dir" ] || { echo "snapshot: no snapshots for '$proj'." >&2; exit 1; }

  # ── select snapshot to restore ──────────────────────────────────────────
  if [[ -z "$requested" || "$requested" == "1" ]]; then        # newest
    target=$(ls -1t "$snap_dir"/*.snapshot 2>/dev/null | head -n1)
  elif [[ "$requested" =~ ^[0-9]+$ ]]; then                    # N-th newest
    idx="$requested"
    target=$(ls -1t "$snap_dir"/*.snapshot 2>/dev/null | sed -n "${idx}p")
  else                                                         # explicit name
    [[ "$requested" == *.snapshot ]] || requested="${requested}.snapshot"
    if [[ "$requested" == */* && -f "$requested" ]]; then
      target="$requested"            # absolute / relative path
    else
      target="$snap_dir/$requested"
    fi
  fi

  # ── sanity checks ───────────────────────────────────────────────────────
  if [[ -z "${target:-}" || ! -f "$target" ]]; then
    if [[ "$requested" =~ ^[0-9]+$ ]]; then
      echo "snapshot: no ${requested}-th newest snapshot in $snap_dir." >&2
    else
      echo "snapshot: '${requested:-}' not found in $snap_dir." >&2
    fi
    exit 1
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
