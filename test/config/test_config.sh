#!/usr/bin/env bash
#
# Minimal test for config/-c/--config in both forms.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT; cd "$tmpdir"; git init -q

cat > global.json <<'EOF'
{"foo":"bar"}
EOF

mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null

###############################################################################
# Expected JSON prefix (everything up to the arrays, so we can              #
# string-match while ignoring dynamic whitespace that jq may emit later).   #
###############################################################################
expected=$'{\n  "project": "",\n  "version": "",\n  "owner": "",\n  "description": null,\n  "settings": {\n    "types_tracked": [],\n    "preferences": {"separators": true}\n  },\n  "ignore_file": [],\n  "ignore_path": []\n}'

###############################################################################
# 1. ── PREFIX: --config / -c ──
###############################################################################
echo "── PREFIX: --config / -c ──"
for cmd in --config -c; do
  out=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$cmd")
  [[ "$out" == "$expected"* ]] && echo "  - config ($cmd) ✅" || {
    echo "  - config ($cmd) ❌"; echo "Got:"; printf '%s\n' "$out"; exit 1; }
done

###############################################################################
# 2. ── BARE: config ──
###############################################################################
echo "── BARE: config ──"
out2=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh config)
[[ "$out2" == "$expected"* ]] && echo "  - config (bare) ✅" || {
  echo "  - config (bare) ❌"; echo "Got:"; printf '%s\n' "$out2"; exit 1; }

echo "✅ test/test_config.sh"
