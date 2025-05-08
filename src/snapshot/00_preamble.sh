#!/usr/bin/env bash
#
# snapshot - quick Git‑aware project dumper / tree / clipboard / config helper
# (section 0 from the former monolithic script)
#
set -euo pipefail
no_snapshot=false
# only shift off --no-snapshot if present, safely under set -u
if [[ "${1:-}" == "--no-snapshot" ]]; then
  no_snapshot=true
  shift
fi

###############################################################################
# 0. Locate global config (overridable via $SNAPSHOT_CONFIG)
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"
