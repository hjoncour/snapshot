#!/usr/bin/env bash
#
# snapshot – quick Git-aware project dumper / tree / clipboard / config helper
# (section 0 of the modular implementation)
#
set -euo pipefail

###############################################################################
# 0. Global flags & defaults (all must be *defined* when “set -u” is active)
###############################################################################
no_snapshot=false
do_copy=false
do_print=false
ignore_test=false
custom_names=()
tags=()
dest_dirs=()
verbosity_override=""

# ⬇ NEW: keep this array *always* defined so later code can safely test
#        ${#filter_tags[@]} even under “set -u”.
filter_tags=()

###############################################################################
# 1. Parse *leading* global flags
#    (--no-snapshot, --copy, --print, --ignore-test, --name, --tag, --to, --verbose:LEVEL))
###############################################################################
while [[ "${1:-}" =~ ^-- ]]; do
  case "$1" in
    --no-snapshot)
      no_snapshot=true;
      shift ;;
    --copy)
      do_copy=true;
      shift ;;
    --print)         
      do_print=true;   
      shift ;;
    --ignore-test)
      ignore_test=true; 
      shift ;;
    --name)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        custom_names+=("$1");
        shift
      done ;;
      --name=*)
      custom_names+=("${1#--name=}"); shift ;;
    --tag)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        tags+=("$1"); shift
      done ;;
    --tag=*)         
      tags+=("${1#--tag=}"); shift ;;

    --to)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        dest_dirs+=("$1"); shift
      done ;;
    --to=*)           
      dest_dirs+=("${1#--to=}"); shift ;;
    --verbose:*)
      verbosity_override="${1#--verbose:}"
      case "$verbosity_override" in
        mute|minimal|normal|verbose|debug) ;;
        *) echo "snapshot: use --verbose:mute|minimal|normal|verbose|debug" >&2
           exit 2 ;;
      esac
      shift ;;
    *) break ;;
  esac
done

###############################################################################
# 2. Locate *global* configuration file
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"

# If the caller didn’t give --verbose:… fall back to the stored preference
if [[ -z "$verbosity_override" ]]; then
  verbosity_override=$(jq -r '.settings.preferences.verbose // "normal"' \
                       "$global_cfg")
fi
