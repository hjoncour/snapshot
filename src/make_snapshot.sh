#!/usr/bin/env bash
#
# make_snapshot.sh – concatenate ordered modules to stdout
#
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/snapshot"

modules=(
  "$dir/preamble.sh"
  "$dir/helpers.sh"
  "$dir/git.sh"
  "$dir/ignore.sh"
  "$dir/regex.sh"
  "$dir/core/dump.sh"
  "$dir/core/save.sh"
  "$dir/core/restore.sh"
  "$dir/core/archive.sh"
  "$dir/core/list.sh"
  "$dir/core/where.sh"
  "$dir/dispatch.sh"
)

for m in "${modules[@]}"; do
  [[ -f $m ]] || { echo "make_snapshot: missing $m" >&2; exit 1; }
  cat "$m"
done
