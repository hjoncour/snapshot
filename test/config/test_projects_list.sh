#!/usr/bin/env bash
#
# test_projects_list.sh – verify --projects listing & sorting logic
#

set -euo pipefail

###############################################################################
# 0. Locate the real repo (needed to build the snapshot stub)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Create an isolated HOME + stub snapshot binary
###############################################################################
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME="$tmp_home"

support_dir="$HOME/Library/Application Support/snapshot"
mkdir -p "$support_dir"

# Build the one-file snapshot stub into $tmp_home/snapshot
bash "$repo_root/src/make_snapshot.sh" > "$tmp_home/snapshot"
chmod +x "$tmp_home/snapshot"
snap() { SNAPSHOT_CONFIG="$HOME/global.json" "$tmp_home/snapshot" "$@"; }

###############################################################################
# 2. Populate three dummy projects (alpha, beta, omega)
###############################################################################
for p in alpha beta omega; do
  mkdir -p "$support_dir/$p"
done

# Create at least one snapshot file in two projects so that --details works
touch "$support_dir/alpha/a.snapshot"
touch "$support_dir/omega/z.snapshot"

###############################################################################
# 3. Run checks
###############################################################################
fail=0
ok () { printf '  - %s ✅\n' "$1"; }
ko () { printf '  - %s ❌\n' "$1"; fail=1; }

######################## alphabetical (default) ###############################
expected=$'alpha\nbeta\nomega'
out=$(snap --projects)
[[ "$out" == "$expected" ]] && ok "alphabetical list" || ko "alphabetical list"

######################## reverse order ########################################
expected_rev=$'omega\nbeta\nalpha'
out_rev=$(snap --projects desc:name)
[[ "$out_rev" == "$expected_rev" ]] && ok "reverse list" || ko "reverse list"

######################## details + size sort ##################################
#   (Just a quick smoke-test: ensure header appears and rows count = 3)
#details=$(snap --projects details asc:size)
#rows=$(printf '%s\n' "$details" | tail -n +3 | wc -l | tr -d ' ')
#[[ "$rows" -eq 3 ]] && ok "details view" || ko "details view"

###############################################################################
# 4. Final exit status
###############################################################################
exit "$fail"
