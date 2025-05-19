#!/usr/bin/env bash
###############################################################################
# test.sh — run every snapshot test under test/ and summarise results
###############################################################################

set -uo pipefail

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

###############################################################################
# ensure snapshot writes into support dir
###############################################################################
mkdir -p "$HOME/Library/Application Support/snapshot"

###############################################################################
# 3) execute every test script under test/ prefixed test_*.sh
###############################################################################
passed_list=$(mktemp)
failed_list=$(mktemp)

tests_list=$(find test -type f -name 'test_*.sh' | sort)
while IFS= read -r test; do
  # echo "\n→ $test"
  if bash "$test"; then
    printf '%s\n' "$test" >> "$passed_list"
  else
    printf '%s\n' "$test" >> "$failed_list"
  fi
done <<EOF
$tests_list
EOF

###############################################################################
# 4) print a neat summary
###############################################################################
echo
echo "──────── summary ────────"

while IFS= read -r t; do
  printf '✅ %s\n' "$t"
done < "$passed_list"

if [ -s "$failed_list" ]; then
  while IFS= read -r t; do
    printf '❌ %s\n' "$t"
  done < "$failed_list"
fi
echo

###############################################################################
# 5) final exit code
###############################################################################
if [ -s "$failed_list" ]; then
  fail_count=$(wc -l < "$failed_list")
  echo "❌  ${fail_count} test(s) failed."
  rm "$passed_list" "$failed_list"
  exit 1
else
  echo "✅  All snapshot tests passed!"
  rm "$passed_list" "$failed_list"
  exit 0
fi
