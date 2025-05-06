#!/usr/bin/env bash
#
# snapshot – Git‑aware project dumper / tree / clipboard / config helper
#
# USAGE
#   snapshot tree                        # show repo structure
#   snapshot                             # dump every code / config file
#   snapshot code                        # explicit alias of the default
#   snapshot copy                        # dump → clipboard (macOS pbcopy)
#   snapshot --config  | -c              # show global config.json
#   snapshot --ignore   | -i ITEM…       # add ITEM(s) to ignore list
#   snapshot --add-type EXT …            # track additional file‑extensions
#   snapshot --remove-type EXT …         # stop tracking given file‑extensions
#
set -euo pipefail

###############################################################################
# 0. Locate global config
###############################################################################
cfg_dir="$HOME/Library/Application Support/snapshot"
global_cfg="${SNAPSHOT_CONFIG:-$cfg_dir/config.json}"
mkdir -p "$(dirname "$global_cfg")"
[ -f "$global_cfg" ] || echo '{}' > "$global_cfg"

###############################################################################
# 1. jq helpers
###############################################################################
need_jq() { command -v jq >/dev/null 2>&1 && return; echo "snapshot: '$1' needs jq." >&2; exit 1; }

show_config() { cat "$global_cfg"; }

default_types=( sh bash zsh ksh c cc cpp h hpp java kt go rs py js ts jsx tsx rb php pl swift scala dart cs sql html css scss md json yaml yml toml ini cfg conf env xml gradle mk )

ensure_arrays() {
  need_jq "arrays"
  jq --argjson defs "$(printf '%s\n' "${default_types[@]}" | jq -R . | jq -s .)" '
    .types_tracked = (.types_tracked // $defs) |
    .types_ignored = (.types_ignored // [])   |
    .ignore_file   = (.ignore_file   // [])   |
    .ignore_path   = (.ignore_path   // [])
  ' "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
}


###############################################################################
# 2. ignore helpers (files vs paths/globs)
###############################################################################
add_ignores() {
  ensure_arrays; need_jq "--ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: --ignore needs at least one item." >&2; exit 2; }
  for itm in "$@"; do
    if [[ "$itm" == */* || "$itm" == *'*'* || "$itm" == *'?'* || "$itm" == .* ]]; then
      jq --arg p "$itm" '.ignore_path += [$p] | .ignore_path |= unique' \
         "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
      echo "snapshot: added '$itm' to ignore_path."
    else
      jq --arg f "$itm" '.ignore_file += [$f] | .ignore_file |= unique' \
         "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"
      echo "snapshot: added '$itm' to ignore_file."
    fi
  done
}

###############################################################################
# 3. type helpers
###############################################################################
add_type()     { ensure_arrays; for e in "$@"; do e=${e#.}; e=${e,,}; jq --arg e "$e" '.types_tracked += [$e] | .types_tracked |= unique' "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"; echo "snapshot: added type '$e'."; done; }
remove_type()  { ensure_arrays; for e in "$@"; do e=${e#.}; e=${e,,}; jq --arg e "$e" '.types_tracked |= map(select(.!= $e))' "$global_cfg" > "$global_cfg.tmp" && mv "$global_cfg.tmp" "$global_cfg"; echo "snapshot: removed type '$e'."; done; }

###############################################################################
# 4. Git repo & tracked files
###############################################################################
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "snapshot: error – not inside a Git repository." >&2; exit 1; fi
cd "$git_root"
tracked_files=$(git ls-files)

###############################################################################
# 5. Build ignore logic
###############################################################################
ensure_arrays
ignore_file=$(jq -r '.ignore_file[]?' "$global_cfg")
ignore_file_lc=$(printf '%s\n' $ignore_file | tr '[:upper:]' '[:lower:]')
ignore_path=$(jq -r '.ignore_path[]?' "$global_cfg")

is_ignored() {
  local p="$1"
  local base="${p##*/}"
  local lc="${base,,}"
  [[ -n "$ignore_file_lc" ]] && printf '%s\n' $ignore_file_lc | grep -qFx -- "$lc" && return 0
  if [[ -n "$ignore_path" ]]; then
    while IFS= read -r pat; do
      [[ -z "$pat" ]] && continue
      [[ "$p" == $pat ]] && return 0
    done <<< "$ignore_path"
  fi
  return 1
}

###############################################################################
# 6. Build extension regex
###############################################################################
tracked_exts=$(jq -r '.types_tracked[]?' "$global_cfg" | tr '[:upper:]' '[:lower:]')
ignored_exts=$(jq -r '.types_ignored[]?' "$global_cfg" | tr '[:upper:]' '[:lower:]')
exts=()
for e in $tracked_exts; do skip=0; for ig in $ignored_exts; do [[ $e == "$ig" ]] && { skip=1; break; }; done; [[ $skip -eq 0 ]] && exts+=("$e"); done
ext_pat="\\.($(IFS='|'; echo "${exts[*]}"))$"
static_files='(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'
code_regex="$ext_pat|$static_files"

###############################################################################
# 7. Dump helpers
###############################################################################
dump_code() {
  printf '%s\n' "$tracked_files" | grep -E -i "$code_regex" |
  while IFS= read -r f; do is_ignored "$f" && continue; printf '\n===== %s =====\n' "$f"; cat -- "$f"; done
}
filtered_tree() { printf '%s\n' "$tracked_files" | while IFS= read -r f; do is_ignored "$f" || printf '%s\n' "$f"; done; }

###############################################################################
# 8. Dispatch
###############################################################################
cmd="${1:-code}"
case "$cmd" in
  tree)   command -v tree >/dev/null 2>&1 || { echo "snapshot: install 'tree' first."; exit 1; }
          filtered_tree | tree --fromfile ;;
  code)   dump_code ;;
  copy)   command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: pbcopy not found."; exit 1; }
          bytes=$(dump_code | tee >(wc -c) | pbcopy | tail -1); echo "snapshot: copied $bytes bytes to clipboard." ;;
  --config|-c|config)      show_config ;;
  --ignore|-i|ignore)      shift; add_ignores "$@" ;;
  --add-type)              shift; add_type "$@" ;;
  --remove-type)           shift; remove_type "$@" ;;
  *) echo "snapshot: error – unknown command '$cmd'"; echo "usage: snapshot [tree|code|copy|--config|--ignore|--add-type|--remove-type]" >&2; exit 2 ;;
esac
