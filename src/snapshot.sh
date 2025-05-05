#!/usr/bin/env bash
#
# snapshot – quick Git‑aware project dumper / tree / clipboard / config helper
#
# USAGE
#   snapshot tree                    # show repo structure (tracked files only)
#   snapshot                         # dump every code / config file
#   snapshot code                    # explicit alias of the default
#   snapshot copy                    # dump → clipboard (macOS pbcopy)
#   snapshot --config  | -c          # print the global config.json
#   snapshot --ignore  | -i FILE…    # add FILE name(s) to ignore_file list
#
set -euo pipefail

###############################################################################
# 0. Locate global config (overridable for tests with $SNAPSHOT_CONFIG)
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"   # always exists

###############################################################################
# 1. Helpers
###############################################################################
need_jq() {
  command -v jq >/dev/null 2>&1 && return
  echo "snapshot: error – '$1' requires jq (not found in PATH)." >&2
  exit 1
}

show_config() { cat "$global_cfg"; }

add_ignores() {
  need_jq "--ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error – --ignore needs filenames." >&2; exit 2; }

  for fname in "$@"; do
    jq --arg fname "$fname" \
       '.ignore_file = ((.ignore_file // []) + [$fname] | unique)' \
       "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
  done
  echo "snapshot: added $* to ignore_file list."
}

###############################################################################
# 2. Ensure we’re inside a Git repo & gather tracked files
###############################################################################
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "snapshot: error – not inside a Git repository." >&2
  exit 1
fi
cd "$git_root"
tracked_files=$(git ls-files)

# ---------------------------------------------------------------------------
# Exclude files whose **basename** appears in ignore_file (case‑insensitive)
# ---------------------------------------------------------------------------
ignore_names=$(jq -r '.ignore_file[]?' "$global_cfg" 2>/dev/null || true)
ignore_names_lower=$(printf '%s\n' $ignore_names | tr '[:upper:]' '[:lower:]')

is_ignored() {
  local base lcbase
  base="$(basename "$1")"
  lcbase=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
  printf '%s\n' $ignore_names_lower | grep -qFx -- "$lcbase"
}

###############################################################################
# 3. Regex for code / config files
###############################################################################
exts='\.(sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|ya?ml|toml|ini|cfg|conf|env|xml|gradle|mk?)$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'

###############################################################################
# 4. Core dumping routines
###############################################################################
dump_code() {
  printf '%s\n' "$tracked_files" | grep -E -i "$exts" |
  while IFS= read -r f; do
    is_ignored "$f" && continue
    printf '\n===== %s =====\n' "$f"
    cat -- "$f"
  done
}

filtered_for_tree() {
  printf '%s\n' "$tracked_files" | while IFS= read -r f; do
    is_ignored "$f" || printf '%s\n' "$f"
  done
}

###############################################################################
# 5. Dispatch
###############################################################################
cmd="${1:-code}"
case "$cmd" in
  tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: error – install 'tree'."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  code) dump_code ;;

  copy)
    command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: error – pbcopy not found."; exit 1; }
    bytes=$(dump_code | tee >(wc -c) | pbcopy | tail -1)
    echo "snapshot: copied $bytes bytes to clipboard."
    ;;

  --config|-c|config)        show_config ;;

  --ignore|-i|ignore) shift; add_ignores "$@" ;;

  *)
    echo "snapshot: error – unknown command '$cmd'" >&2
    echo "usage: snapshot [tree|code|copy|--config|--ignore]" >&2
    exit 2
    ;;
esac
