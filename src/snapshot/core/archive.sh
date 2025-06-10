#!/usr/bin/env bash
#
# snapshot/core/archive.sh – archive_snapshots
#
set -euo pipefail

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
