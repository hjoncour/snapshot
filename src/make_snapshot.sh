#!/usr/bin/env bash
#
# make_snapshot.sh - concatenate numbered modules to stdout
#
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/snapshot"
cat "$dir"/[0-9][0-9]_*.sh
