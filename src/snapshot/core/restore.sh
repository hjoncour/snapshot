#!/usr/bin/env bash
#
# snapshot/core/restore.sh – restore_snapshot
#
set -euo pipefail

###############################################################################
# 3. Restore snapshot                                                         #
#   snapshot restore            → newest
#   snapshot restore N          → N-th newest (1 = newest)
#   snapshot restore FILE       → exact file (adds .snapshot if missing)
###############################################################################
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
