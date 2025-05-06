#!/usr/bin/env bash
#
# snapshot - quick Git‑aware project dumper / tree / clipboard / config helper
#
# USAGE
#   snapshot tree                       # show repo structure (tracked files only)
#   snapshot                            # dump every code / config file
#   snapshot code                       # explicit alias of the default
#   snapshot copy                       # dump → clipboard (macOS pbcopy)
#   snapshot --config  | -c             # print the global config.json
#   snapshot --ignore  | -i ITEM…       # add ITEM(s) to ignore list
#                                         • plain names  → ignore_file
#                                         • paths / globs → ignore_path
#
set -euo pipefail

###############################################################################
# 0. Locate global config (overridable via $SNAPSHOT_CONFIG)
###############################################################################
cfg_default_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_default_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"

###############################################################################
# 1. Helpers
###############################################################################
need_jq() {
  command -v jq >/dev/null 2>&1 && return
  echo "snapshot: error - '$1' requires jq (not found in PATH)." >&2
  exit 1
}

show_config() { cat "$global_cfg"; }

add_ignores() {
  need_jq "--ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --ignore needs arguments." >&2; exit 2; }

  for item in "$@"; do
    if [[ "$item" == */* || "$item" == *'*'* || "$item" == *'?'* || "$item" == .* ]]; then
      jq --arg p "$item" \
         '.ignore_path = ((.ignore_path // []) + [$p] | unique)' \
         "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
      echo "snapshot: added '$item' to ignore_path."
    else
      jq --arg f "$item" \
         '.ignore_file = ((.ignore_file // []) + [$f] | unique)' \
         "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
      echo "snapshot: added '$item' to ignore_file."
    fi
  done
}

###############################################################################
# 2. Ensure we’re inside a Git repo & gather tracked files
###############################################################################
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "snapshot: error - not inside a Git repository." >&2
  exit 1
fi
cd "$git_root"
tracked_files=$(git ls-files)

###############################################################################
# 3. Build ignore lists
###############################################################################
ignore_files=$(jq -r '.ignore_file[]?' "$global_cfg" 2>/dev/null || true)
ignore_files_lc=$(printf '%s\n' $ignore_files | tr '[:upper:]' '[:lower:]')
ignore_paths=$(jq -r '.ignore_path[]?' "$global_cfg" 2>/dev/null || true)

shopt -s extglob 2>/dev/null || true
shopt -s globstar 2>/dev/null || true

is_ignored() {
  local path="$1"
  # 3‑a) basename match (case‑insensitive)
  local base lcbase
  base="${path##*/}"
  lcbase=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
  if [[ -n "$ignore_files_lc" ]] && printf '%s\n' $ignore_files_lc | grep -qFx -- "$lcbase"; then
    return 0
  fi
  # 3‑b) path / glob match
  if [[ -n "$ignore_paths" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      [[ "$path" == $pattern ]] && return 0
    done <<< "$ignore_paths"
  fi
  return 1
}

###############################################################################
# 4. Regex for code / config files
###############################################################################
exts='\.(sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|ya?ml|toml|ini|cfg|conf|env|xml|gradle|mk?)$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'

###############################################################################
# 5. Core dumping routines
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
# 6. Dispatch
###############################################################################
cmd="${1:-code}"
case "$cmd" in
  tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: error - install 'tree'."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  code) dump_code ;;

  copy)
    command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: error - pbcopy not found."; exit 1; }
    bytes=$(dump_code | tee >(wc -c) | pbcopy | tail -1)
    echo "snapshot: copied $bytes bytes to clipboard."
    ;;

  --config|-c|config) show_config ;;

  --ignore|-i|ignore) shift; add_ignores "$@" ;;

  *)
    echo "snapshot: error - unknown command '$cmd'" >&2
    echo "usage: snapshot [tree|code|copy|--config|--ignore]" >&2
    exit 2 ;;
esac
