#!/usr/bin/env bash
#
# snapshot - quick Git-aware project dumper / tree / clipboard / config helper
# (section 0 from the former monolithic script)
#
set -euo pipefail
# initialise our flags & guard against unbound
no_snapshot=false
do_copy=false
do_print=false
SNAPSHOT_FILE=""

# pull off any leading global flags
while [[ "${1:-}" =~ ^-- ]]; do
  case "$1" in
    --no-snapshot) no_snapshot=true; shift ;;
    --copy)        do_copy=true;    shift ;;
    --print)       do_print=true;   shift ;;
    *) break ;;
  esac
done

###############################################################################
# 0. Locate global config (overridable via $SNAPSHOT_CONFIG)
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"
