#!/usr/bin/env bash
#
# test/run-all.sh — run every snapshot test and summarise results
#
set -uo pipefail           # (intentionally omit -e so we can collect failures)

###############################################################################
# 1) create a throw-away $HOME so nothing touches the real user’s config
###############################################################################
TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"

###############################################################################
# 2) point snapshot at an isolated global config
###############################################################################
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{}' > "$SNAPSHOT_CONFIG"

# snapshot will also write dumps to the usual support directory
mkdir -p "$HOME/Library/Application Support/snapshot"

###############################################################################
# 3) execute every test script, tracking which ones pass / fail
###############################################################################
passed=()
failed=()

for test in test/test_*.sh; do
  echo "→ $test"
  if bash "$test"; then
    passed+=("$test")
  else
    failed+=("$test")
  fi
done

###############################################################################
# 4) print a neat summary
###############################################################################
echo
echo "──────── summary ────────"
for t in "${passed[@]}";  do printf '✅ %s\n' "$t"; done

if ((${#failed[@]})); then
  for t in "${failed[@]}";  do printf '❌ %s\n' "$t"; done
fi
echo

###############################################################################
# 5) final exit code
###############################################################################
if ((${#failed[@]} == 0)); then
  echo "✅  All snapshot tests passed!"
  exit 0
else
  echo "❌  ${#failed[@]} test(s) failed."
  exit 1
fi
