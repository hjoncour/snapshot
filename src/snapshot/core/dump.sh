#!/usr/bin/env bash
#
# snapshot/core/dump.sh – dump helpers
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
  ###########################################################################
  # A. Repository tree header (always first in the dump)
  ###########################################################################
  local tree_listing
  if command -v tree >/dev/null 2>&1; then
    # Use the same filtered file list that the dedicated “tree” command uses,
    # but *never* include ignored files / paths.
    tree_listing=$(filtered_for_tree | tree --fromfile 2>/dev/null)
  else
    # Fallback: plain, newline-separated paths if `tree` is unavailable.
    tree_listing=$(filtered_for_tree)
  fi

  # Emit in the same 5-equals delimiter style used for individual files.
  printf '===== snapshot tree =====\n%s\n' "$tree_listing"

  ###########################################################################
  # B. Individual source files
  ###########################################################################
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
