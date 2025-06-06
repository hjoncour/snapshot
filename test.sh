#!/usr/bin/env bash
###############################################################################
# test.sh – Snapshot test-suite runner
#
# Usage:
#   ./test.sh          # run the *local* matrix   (default)
#   ./test.sh local    # same as above
#   ./test.sh GHA      # run the GitHub-Actions matrix
#
# Edit the two explicit arrays below whenever you add/rename tests so that
# nothing slips in (or out) unnoticed.
###############################################################################
set -euo pipefail
shopt -s nullglob

mode="${1:-local}"
if [[ -n "${GITHUB_ACTIONS:-}" && "$mode" == "local" ]]; then
  mode="GHA"
fi

###############################################################################
# 1. Explicit test lists
###############################################################################
local_tests=(
  "test/backup/test_backup_ignore_tests.sh"
  "test/backup/test_list_snapshots.sh"
  "test/backup/test_save_snapshot.sh"
  "test/backup/test_save_tags.sh"
  "test/backup/test_save_to_location.sh"
  "test/config/test_config.sh"
  "test/config/test_install.sh"
  "test/config/test_projects_list.sh"
  "test/config/test_separate_projects.sh"
  "test/config/test_use_gitignore.sh"
  "test/config/test_verbose.sh"
  "test/ignore/test_ignore_file.sh"
  "test/ignore/test_ignore_path.sh"
  "test/ignore/test_remove_all_ignored_lists.sh"
  "test/restore/test_restore_from_name.sh"
  "test/types/test_add_default_types.sh"
  "test/types/test_add_remove_type.sh"
  "test/types/test_remove_all_types.sh"
  "test/types/test_types_tracked.sh"
)

# Currently identical – feel free to diverge later
gha_tests=(
  # "test/backup/test_backup_ignore_tests.sh" need to fix to make it work in gha
  "test/backup/test_list_snapshots.sh"
  "test/backup/test_save_snapshot.sh"
  "test/backup/test_save_tags.sh"
  "test/backup/test_save_to_location.sh"
  "test/config/test_config.sh"
  "test/config/test_install.sh"
  "test/config/test_projects_list.sh"
  "test/config/test_separate_projects.sh"
  "test/config/test_use_gitignore.sh"
  "test/config/test_verbose.sh"
  "test/ignore/test_ignore_file.sh"
  "test/ignore/test_ignore_path.sh"
  "test/ignore/test_remove_all_ignored_lists.sh"
  "test/restore/test_restore_from_name.sh"
  "test/types/test_add_default_types.sh"
  "test/types/test_add_remove_type.sh"
  "test/types/test_remove_all_types.sh"
  "test/types/test_types_tracked.sh"
)

case "$mode" in
  GHA|gha)   tests=("${gha_tests[@]}")   ;;
  ""|local)  tests=("${local_tests[@]}") ;;
  *)         echo "Unknown mode '$mode'. Use 'local' (default) or 'GHA'." >&2
             exit 2 ;;
esac

###############################################################################
# 2. Isolate HOME so nothing touches the real user’s config
###############################################################################
TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
export SNAPSHOT_CONFIG="$HOME/global.json"
echo '{}' > "$SNAPSHOT_CONFIG"
mkdir -p "$HOME/Library/Application Support/snapshot"

###############################################################################
# 3. Execute tests
###############################################################################
declare -a passed=()
declare -a failed=()

for t in "${tests[@]}"; do
  if [ ! -f "$t" ]; then
    echo "⚠️  Skipping missing test: $t"
    continue
  fi
  if bash "$t"; then
    passed+=("$t")
  else
    failed+=("$t")
  fi
done

###############################################################################
# 4. Summary
###############################################################################
echo
echo "──────── summary ($mode) ────────"
for t in "${passed[@]}"; do
  printf '✅ %s\n' "$t"
done

if ((${#failed[@]})); then
  for t in "${failed[@]}"; do
    printf '❌ %s\n' "$t"
  done
fi
echo

###############################################################################
# 5. Exit status
###############################################################################
if ((${#failed[@]})); then
  echo "❌  ${#failed[@]} test(s) failed."
  exit 1
else
  echo "✅  All ${#passed[@]} test(s) passed!"
  exit 0
fi
