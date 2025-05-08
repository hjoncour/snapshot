#!/usr/bin/env bash
#
# Validate that settings.types_tracked overrides the built‑in extension list.
#
set -euo pipefail

# locate the real repo to pick up make_snapshot.sh
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

###############################################################################
# 1. Create sample files
###############################################################################
echo 'console.log("hi");' > foo.js     # default‑tracked, should disappear
echo '#include <stdio.h>'   > bar.c     # default‑tracked, should disappear
echo 'plain text'           > note.txt  # **custom‑tracked**, should remain
echo '{}'                   > config.json

###############################################################################
# 2. Assemble snapshot
###############################################################################
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh
git add . >/dev/null   # so git ls-files sees the files

###############################################################################
# 3. Provide a custom global config that tracks ONLY *.txt
###############################################################################
cat > global.json <<'EOF'
{
  "settings": {
    "types_tracked": ["txt"]
  }
}
EOF

###############################################################################
# 4. Run snapshot and assert results
###############################################################################
dump=$(SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh code)

echo "$dump" | grep -q '===== note.txt =====' || {
  echo "❌ types_tracked failed – note.txt missing" >&2
  exit 1
}

for banned in foo.js bar.c; do
  if echo "$dump" | grep -q "===== $banned ====="; then
    echo "❌ types_tracked failed – saw $banned but it should be excluded" >&2
    exit 1
  fi
done

echo "✅ settings.types_tracked overrides extension list correctly"
