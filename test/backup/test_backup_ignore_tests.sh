#!/usr/bin/env bash
#
# test_ignore_test_flag.sh ─ verify that  --ignore-test
# really excludes everything under:
#   • test/**           • tests/**
#   • **/__tests__/**   • **/*.test.*   • **/*_test.*
#
set -euo pipefail

###############################################################################
# 0. Locate the repo root (needed to build the one-file stub)
###############################################################################
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/../.." rev-parse --show-toplevel)"

###############################################################################
# 1. Isolated HOME + tiny Git repo with a few test files
###############################################################################
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
mkdir -p "$HOME"

cd "$tmpdir"
git init -q

# — ordinary source file (must *always* appear) —
echo 'console.log("prod");'  > app.js

# — a handful of “test” files —
mkdir -p test/unit              tests/integration   src/__tests__/deep
echo 'console.log("t1");' > test/unit/foo.test.js
echo 'console.log("t2");' > tests/integration/bar_test.py
echo 'console.log("t3");' > src/__tests__/deep/baz.js

git add . >/dev/null
git commit -m init -q

###############################################################################
# 2. Build snapshot stub (single concatenated script)
###############################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }
printf '{}' > "$tmpdir/global.json"

###############################################################################
# 3. Run:  without  vs  with  --ignore-test
###############################################################################
raw_full=$(snap --print)                    # baseline – should include test files
raw_skip=$(snap --ignore-test --print)      # should *exclude* them

###############################################################################
# 4. Assertions
###############################################################################
fail=0
ok() { printf '  - %s ✅\n' "$1"; }
ko() { printf '  - %s ❌\n' "$1"; fail=1; }

# helper: count headers for a path pattern inside a dump
count_headers () {
  local pattern="$1" dump="$2"
  grep -c "^===== ${pattern} =====" <<<"$dump" || true
}

############ ordinary source file must stay ############
prod1=$(count_headers "app.js" "$raw_full")
prod2=$(count_headers "app.js" "$raw_skip")
[[ $prod1 -eq 1 && $prod2 -eq 1 ]] && ok "non-test file retained" \
                                    || ko "non-test file retained"

############ every test file must disappear ############
for tst in \
  "test/unit/foo.test.js" \
  "tests/integration/bar_test.py" \
  "src/__tests__/deep/baz.js"
do
  before=$(count_headers "$tst" "$raw_full")
  after=$(count_headers  "$tst" "$raw_skip")
  if [[ $before -eq 1 && $after -eq 0 ]]; then
    ok "$tst excluded"
  else
    ko "$tst excluded"
  fi
done

###############################################################################
# 5. Finish
###############################################################################
exit "$fail"
