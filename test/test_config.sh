#!/usr/bin/env bash
#
# Minimal test for “snapshot --config”.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

cat > global.json <<'EOF'
{"foo":"bar"}
EOF

# copy snapshot into this repo
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null   # so git ls-files works

# expected default pretty-printed config output
expected=$'{\n  "project": \"\",\n  "version": \"\",\n  "owner": \"\",\n  "description\": null,\n  "settings\": {\n    "types_tracked\": []\n  },\n  "ignore_file\": [],\n  "ignore_path\": []\n}'

output=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --config)

if [[ "$output" == "$expected" ]]; then
  echo "✅ snapshot --config returned default pretty output"
else
  echo "❌ snapshot --config returned unexpected output"
  echo "expected: $expected"
  echo "got:      $output"
  exit 1
fi
