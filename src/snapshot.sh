#!/usr/bin/env bash
#
# snapshot - quick Git-aware project dumper / tree / clipboard helper
#
# USAGE
#   snapshot tree         # show repo structure (tracked files only)
#   snapshot              # dump every code / config file
#   snapshot code         # explicit alias of the default
#   snapshot copy         # dump → clipboard (macOS pbcopy)
#
set -euo pipefail

###############################################################################
# 0. Verify we are inside a Git repository
###############################################################################
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "snapshot: error - not inside a Git repository." >&2
  exit 1
fi
cd "$git_root"

###############################################################################
# 1. Common data
###############################################################################
tracked_files=$(git ls-files)

# single-line, BSD-grep-friendly regex of “code/config” extensions & filenames
exts='\.(sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|ya?ml|toml|ini|cfg|conf|env|xml|gradle|mk?)$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'

dump_code() {
  echo "$tracked_files" | grep -E -i "$exts" |
  while IFS= read -r f; do
    printf '\n===== %s =====\n' "$f"
    cat -- "$f"
  done
}

###############################################################################
# 2. Dispatch
###############################################################################
cmd="${1:-code}"

case "$cmd" in
  tree)
    if ! command -v tree >/dev/null 2>&1; then
      echo "snapshot: error - 'tree' command not found. Install it first." >&2
      exit 1
    fi
    echo "$tracked_files" | tree --fromfile
    ;;

  code)
    dump_code
    ;;

  copy)
    if ! command -v pbcopy >/dev/null 2>&1; then
      echo "snapshot: error - clipboard tool 'pbcopy' not found (non-macOS?)." >&2
      exit 1
    fi
    bytes=$(dump_code | tee >(wc -c) | pbcopy | tail -1)
    echo "snapshot: copied $bytes bytes to clipboard."
    ;;

  *)
    echo "snapshot: error - unknown sub-command '$cmd'" >&2
    echo "usage: snapshot [tree|code|copy]" >&2
    exit 2
    ;;
esac
