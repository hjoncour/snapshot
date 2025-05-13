#!/usr/bin/env bash
#
# test/run-all.sh — run every snapshot test and summarise results
#
set -uo pipefail           # **note**: deliberately *omit* “-e”

# 1) create a throw-away $HOME
TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"

# 2) point the tool at an isolated config.json
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{}' > "$SNAPSHOT_CONFIG"

# 3) ensure the support dir exists
mkdir -p "$HOME/Library/Application Support/snapshot"

###############################################################################
# 4) run every test, collecting pass / fail status
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
# 5) summary
###############################################################################
echo
echo "──────── summary ────────"
for t in "${passed[@]}";  do printf '✅ %s\n' "$t"; done
for t in "${failed[@]}";  do printf '❌ %s\n' "$t"; done
echo

if [ "${#failed[@]}" -eq 0 ]; then
  echo "✅  All snapshot tests passed!"
  exit 0
else
  echo "❌  ${#failed[@]} test(s) failed."
  exit 1
fi
