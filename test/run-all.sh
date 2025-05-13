#!/usr/bin/env bash
#
# test/run-all.sh — run every snapshot test in an isolated $HOME
#

set -euo pipefail

# 1) create a throw-away $HOME
TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"

# 2) point the tool at a temp config.json
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{}' > "$SNAPSHOT_CONFIG"

# 3) ensure the support dir exists
mkdir -p "$HOME/Library/Application Support/snapshot"

# 4) run each test in turn
for test in test/test_*.sh; do
  echo "→ $test"
  bash "$test"
done

echo
echo "✅  All snapshot tests passed!"
