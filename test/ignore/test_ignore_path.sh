#!/usr/bin/env bash
#
# Validate ignore-path feature (path + glob patterns).
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# test files
mkdir -p demo_dir
echo "console.log('hi');" > demo_dir/foo.js
echo "secret data"        > .secret-pass.sh
echo "sample content"     > test.sample.js
echo '{}' > config.json

# assemble snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add -f demo_dir/foo.js .secret-pass.sh test.sample.js config.json >/dev/null

snap() {
  SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh "$@"
}

echo "── PREFIX: --ignore patterns ──"
# before ignoring, all three should appear
initial=$(snap --print)
for f in demo_dir/foo.js .secret-pass.sh test.sample.js; do
  grep -Fq "$f" <<<"$initial" || { echo "  - prefix before missing $f ❌"; exit 1; }
done

# apply ignore patterns
snap --ignore 'demo_dir/*' '.secret-*' 'test.sample.js' >/dev/null

# after ignoring, none should appear
after=$(snap --print)
for f in demo_dir/foo.js .secret-pass.sh test.sample.js; do
  grep -Fq "$f" <<<"$after" && { echo "  - prefix after still saw $f ❌"; exit 1; }
done
echo "  - ignore-path (prefix) ✅"

echo "── BARE: ignore patterns ──"
# reset config
echo '{}' > global.json

# before again
initial2=$(snap print)
for f in demo_dir/foo.js .secret-pass.sh test.sample.js; do
  grep -Fq "$f" <<<"$initial2" || { echo "  - bare before missing $f ❌"; exit 1; }
done

# bare ignore
snap ignore 'demo_dir/*' '.secret-*' 'test.sample.js' >/dev/null

# after bare ignoring, none should appear
after2=$(snap print)
for f in demo_dir/foo.js .secret-pass.sh test.sample.js; do
  grep -Fq "$f" <<<"$after2" && { echo "  - bare after still saw $f ❌"; exit 1; }
done
echo "  - ignore-path (bare) ✅"

echo "✅ test/test_ignore_path.sh"