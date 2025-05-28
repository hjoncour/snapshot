#!/usr/bin/env bash
#
# test_list_snapshots.sh – verify that
#   • snapshot list-snapshots enumerates the *right* files (without “.snapshot”)
#   • the asc/desc sorting by name | size | date works (also sans suffix)
#

set -euo pipefail

###############################################################################
# 0. Locate repo root (needed to build the one-file stub)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Isolated HOME + tiny Git repo
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
mkdir -p "$HOME"

cd "$tmpdir"
git init -q

# Git needs an identity for commits in CI
git config user.email 'ci@example.com'
git config user.name  'CI Test'

# Seed file + initial commit
echo 'console.log("v0");' > foo.js
echo '{}' > config.json
git add foo.js config.json
git commit -m "init" -q

###############################################################################
# 2. Build the snapshot *stub* (one single file) and helper wrapper
###############################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

# Global config – give the project a fixed name so we know the directory
cat > "$tmpdir/global.json" <<'EOF'
{ "project": "demo" }
EOF

support_dir="$HOME/Library/Application Support/snapshot/demo"

###############################################################################
# 3. Helper to (a) grow foo.js   (b) snapshot under a custom name
###############################################################################
make_snap() {
  local name="$1" lines_to_add="$2"
  # enlarge foo.js so each snapshot gets a *different* size
  for ((i=0; i<lines_to_add; i++)); do
    echo "x line $i" >> foo.js
  done
  git add foo.js
  git commit -m "$name" --allow-empty -q
  snap --name "$name" >/dev/null
}

###############################################################################
# 4. Create three snapshots with distinct   NAME / SIZE / DATE
#    (sleep gives distinct mtime → distinct “date” sort key)
###############################################################################
make_snap apple  0     #   smallest file, earliest
sleep 1
make_snap banana 1     #   medium
sleep 1
make_snap cherry 100   #   largest, latest

###############################################################################
# 5-A. Enumeration – make sure list-snapshots prints *exactly* the files
#       (with the “.snapshot” suffix stripped)
###############################################################################
expected_set=$(ls -1 "$support_dir" | sed 's/\.snapshot$//' | sort)
actual_set=$(snap list-snapshots | sed 's/\.snapshot$//' | sort)

if [[ "$actual_set" != "$expected_set" ]]; then
  echo "❌ list-snapshots did not return the correct set of files" >&2
  echo "--- expected ---" >&2; printf '%s\n' "$expected_set" >&2
  echo "--- got ---"      >&2; printf '%s\n' "$actual_set"   >&2
  exit 1
fi
echo "✅ list-snapshots enumerates the correct files"

###############################################################################
# 5-B. Sorting checks (all comparisons without “.snapshot”)
###############################################################################
# Handy strings for the six orderings we expect
asc_name=$'apple\nbanana\ncherry'
desc_name=$'cherry\nbanana\napple'

# Because we *grew* the file on every snapshot:
asc_size=$asc_name
desc_size=$desc_name

# Creation dates increased in the same order;   desc:date reverses it
asc_date=$asc_name
desc_date=$desc_name

fail=0
check_order() {
  local label="$1" expected="$2"; shift 2
  out=$(snap "$@" | sed 's/\.snapshot$//')
  if [[ "$out" == "$expected" ]]; then
    printf '  - %s ✅\n' "$label"
  else
    printf '  - %s ❌\n' "$label"
    echo "--- expected ---"; printf '%s\n' "$expected"
    echo "--- got ---";      printf '%s\n' "$out"
    fail=1
  fi
}

check_order "asc:name"   "$asc_name"   list-snapshots asc:name
check_order "desc:name"  "$desc_name"  list-snapshots desc:name
check_order "asc:size"   "$asc_size"   list-snapshots asc:size
check_order "desc:size"  "$desc_size"  list-snapshots desc:size
check_order "asc:date"   "$asc_date"   list-snapshots asc:date
check_order "desc:date"  "$desc_date"  list-snapshots desc:date

exit "$fail"
