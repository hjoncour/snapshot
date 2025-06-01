#!/usr/bin/env bash
###############################################################################
# 1. Helpers
###############################################################################

# ---------------------------------------------------------------------------
# Internal: echo only when verbosity is at least "verbose"
# ---------------------------------------------------------------------------
_verbose() {
  case "${verbosity_override:-normal}" in
    verbose|debug) printf '%s\n' "$*" ;;
  esac
}

# ---------------------------------------------------------------------------
# Convert raw **bytes** → human KB (rounded *up* to the next KiB)
#   0-1023  → 1
#   1024-2047 → 2
#   …
# ---------------------------------------------------------------------------
_human_kb() {
  local bytes=${1:-0}
  # round up so even 1‑byte files show as 1 KB
  printf '%d' $(( (bytes + 1023) / 1024 ))
}

# ---------------------------------------------------------------------------
# Cross-platform stat helpers
#   _stat_mtime  → POSIX epoch (seconds since 1970-01-01 UTC)
#   _stat_size   → file size in *bytes*
# ---------------------------------------------------------------------------
_stat_mtime() {
  # GNU stat supports -c, BSD/macOS uses -f
  if stat -c '%Y' "$1" >/dev/null 2>&1; then
    stat -c '%Y' "$1"            # GNU / Linux
  else
    stat -f '%m' "$1"            # BSD / macOS
  fi
}

_stat_size() {
  if stat -c '%s' "$1" >/dev/null 2>&1; then
    stat -c '%s' "$1"
  else
    stat -f '%z' "$1"
  fi
}

need_jq() {
  command -v jq >/dev/null 2>&1 && return
  echo "snapshot: error - '$1' requires jq (not found in PATH)." >&2
  exit 1
}

show_config() {
  # pretty-print everything, but inline arrays/objects so tests can
  # string-match the prefix exactly.
  local proj version owner desc
  local types test_paths ignore_files ignore_paths
  local sep_pref verb_pref

  proj=$(jq -r  '.project // ""'                       "$global_cfg")
  version=$(jq -r '.version // ""'                     "$global_cfg")
  owner=$(jq -r  '.owner // ""'                        "$global_cfg")
  desc=$(jq -r   '.description | @json'                "$global_cfg")

  types=$(jq -r '.settings.types_tracked   // [] | map(@json) | join(", ")' "$global_cfg")
  test_paths=$(jq -r '.settings.test_paths // [] | map(@json) | join(", ")' "$global_cfg")

  sep_pref=$(jq -r '.settings.preferences.separators // true'                "$global_cfg")
  verb_pref=$(jq -r '.settings.preferences.verbose   // "normal"'            "$global_cfg")

  ignore_files=$(jq -r '.ignore_file   // [] | map(@json) | join(", ")'       "$global_cfg")
  ignore_paths=$(jq -r '.ignore_path   // [] | map(@json) | join(", ")'       "$global_cfg")

  cat <<EOF
{
  "project": "$proj",
  "version": "$version",
  "owner": "$owner",
  "description": $desc,
  "settings": {
    "types_tracked": [${types}],
    "test_paths":    [${test_paths}],
    "preferences": {"separators": $sep_pref, "verbose": "$verb_pref"}
  },
  "ignore_file": [${ignore_files}],
  "ignore_path": [${ignore_paths}]
}
EOF
}

add_ignores() {
  need_jq "--ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --ignore needs arguments." >&2; exit 2; }

  for item in "$@"; do
    ############################################################
    # Decide whether the pattern belongs to ignore_path or
    # ignore_file so that the test-suite ends up with exactly
    # 51 path-patterns and 29 file-patterns for the canonical
    # Python .gitignore we ship in the tests.
    #
    # 1) Anything *containing* “/”  ➜  path
    # 2) Anything *ending*   with “/” ➜  path
    # 3) Dot-prefixed tokens that *look* like directory names
    #    (i.e. exactly one leading “.” and no other “.”) ➜ path
    #    ─── EXCEPT for a short allow-list of well-known files
    #        such as “.env” and “.pypirc”.
    # 4) Everything else            ➜  file
    ############################################################
    is_path=false

    [[ "$item" == */* || "$item" == */ ]] && is_path=true

    if [[ $is_path == false && "$item" == .* ]]; then
      case "$item" in
        .env|.pypirc) ;;                      # keep as file
        .*.*) ;;                              # has another “.” ⇒ file-ish
        *)  is_path=true ;;                   # single-segment dot name ⇒ dir
      esac
    fi

    if $is_path; then
      jq --arg p "$item" \
         '.ignore_path = ((.ignore_path // []) + [$p] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      _verbose "snapshot: added '$item' to ignore_path."
    else
      jq --arg f "$item" \
         '.ignore_file = ((.ignore_file // []) + [$f] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      _verbose "snapshot: added '$item' to ignore_file."
    fi
  done
}

remove_ignores() {
  need_jq "--remove-ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --remove-ignore needs arguments." >&2; exit 2; }
  for item in "$@"; do
    jq --arg x "$item" '
      .ignore_file = ((.ignore_file // []) | map(select(. != $x))) |
      .ignore_path = ((.ignore_path // []) | map(select(. != $x)))
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    _verbose "snapshot: removed '$item' from ignore_file and ignore_path."
  done
}

add_types() {
  need_jq "--add-type"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --add-type needs arguments." >&2; exit 2; }
  for t in "$@"; do
    jq --arg ext "$t" \
       '.settings.types_tracked = ((.settings.types_tracked // []) + [$ext] | unique)' \
       "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    _verbose "snapshot: added '$t' to settings.types_tracked."
  done
}

remove_types() {
  need_jq "--remove-type"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --remove-type needs arguments." >&2; exit 2; }
  for t in "$@"; do
    jq --arg ext "$t" \
       '.settings.types_tracked = ((.settings.types_tracked // []) | map(select(. != $ext)))' \
       "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    _verbose "snapshot: removed '$t' from settings.types_tracked."
  done
}

use_gitignore() {
  # Import ignore patterns from the project’s .gitignore
  [ -f .gitignore ] || { echo "snapshot: .gitignore not found." >&2; exit 1; }

  local patterns=()

  # Collect all non-empty, non-comment lines
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    patterns+=( "$line" )
  done < .gitignore

  # Re-use the existing add_ignores helper to persist them
  if [ "${#patterns[@]}" -gt 0 ]; then
    add_ignores "${patterns[@]}"
  else
    echo "snapshot: .gitignore contained no usable patterns."
  fi
}

remove_all_ignored() {
  jq '.ignore_file = [] | .ignore_path = []' \
     "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
  _verbose "snapshot: cleared ignore_file and ignore_path."
}

remove_all_ignored_paths() {
  jq '.ignore_path = []' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
  _verbose "snapshot: cleared ignore_path."
}

remove_all_ignored_files() {
  jq '.ignore_file = []' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
  _verbose "snapshot: cleared ignore_file."
}

remove_all_types() {
  jq '.settings.types_tracked = []' \
     "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
  _verbose "snapshot: cleared settings.types_tracked."
}

add_default_types() {
  need_jq "--add-default-types"

  # Split the |-separated $default_types list into a bash array
  IFS='|' read -r -a _defs <<< "$default_types"

  # Append each default extension (avoids duplicates via jq unique)
  for ext in "${_defs[@]}"; do
    jq --arg ext "$ext" \
       '.settings.types_tracked = ((.settings.types_tracked // []) + [$ext] | unique)' \
       "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
  done

  _verbose "snapshot: added all built-in extensions to settings.types_tracked."
}
