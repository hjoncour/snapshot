#!/usr/bin/env bash
#
# test_config.sh – structural smoke-test for `snapshot config`
#
# 1. run `snapshot` under its three accepted flags
# 2. strip trailing `// …` comments so the output is pure JSON
# 3. feed the result to jq and assert the presence / type of a handful
#    of top-level keys (one assertion at a time, to avoid context issues)
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
cd   "$tmpdir";        git init -q

echo '{"foo":"bar"}' > global.json      # tiny starting config

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null

snap() { SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"; }

###############################################################################
# helper – run variant, strip comments, then run independent jq checks
###############################################################################
check () {
  local flag="$1"
  raw=$(snap "$flag")
  clean=$(printf '%s\n' "$raw" | sed -E 's/[[:space:]]*\/\/.*$//')

  # must parse
  echo "$clean" | jq -e type >/dev/null

  # key / type assertions (each with original input)
  for expr in \
    '.project       | type == "string"' \
    '.version       | type == "string"' \
    '.settings      | type == "object"' \
    '.settings.test_paths       | type == "array"' \
    '.settings.types_tracked    | type == "array"' \
    '.settings.preferences.separators | type == "boolean"' \
    '.settings.preferences.verbose    | type == "string"' \
    '.ignore_file  | type == "array"' \
    '.ignore_path  | type == "array"'
  do
    echo "$clean" | jq -e "$expr" >/dev/null || {
      printf '  - config (%s) ❌  failed check: %s\n' "$flag" "$expr"
      exit 1
    }
  done
  printf '  - config (%s) ✅\n' "$flag"
}

echo "── STRUCTURAL CHECKS ──"
for variant in --config -c config; do
  check "$variant"
done

echo "✅ test/test_config.sh"
