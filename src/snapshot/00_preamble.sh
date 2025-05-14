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
custom_names=()
tags=()

# pull off any leading global flags (--no-snapshot, --copy, --print, --name, --tag)
while [[ "${1:-}" =~ ^-- ]]; do
  case "$1" in
    --no-snapshot)
      no_snapshot=true
      shift
      ;;
    --copy)
      do_copy=true
      shift
      ;;
    --print)
      do_print=true
      shift
      ;;
    --name)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        custom_names+=("$1")
        shift
      done
      ;;
    --name=*)
      custom_names+=("${1#--name=}")
      shift
      ;;
    --tag)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        tags+=("$1")
        shift
      done
      ;;
    --tag=*)
      tags+=("${1#--tag=}")
      shift
      ;;
    *)
      break
      ;;
  esac
done

###############################################################################
# 0. Locate global config
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"
