###############################################################################
# 2. Ensure we’re inside a Git repo & gather tracked files
###############################################################################
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "snapshot: error - not inside a Git repository." >&2
  exit 1
fi
cd "$git_root"
tracked_files=$(git ls-files)
