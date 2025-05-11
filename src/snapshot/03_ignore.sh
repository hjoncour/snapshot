###############################################################################
# 3. Build ignore lists
###############################################################################
ignore_files=$(jq -r '.ignore_file[]?' "$global_cfg" 2>/dev/null || true)
ignore_files_lc=$(printf '%s\n' $ignore_files | tr '[:upper:]' '[:lower:]')
ignore_paths=$(jq -r '.ignore_path[]?' "$global_cfg" 2>/dev/null || true)

shopt -s extglob globstar 2>/dev/null || true

is_ignored() {
  local path="$1" base lcbase pattern
  base="${path##*/}"
  lcbase=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
  if [[ -n "$ignore_files_lc" ]] && printf '%s\n' $ignore_files_lc | grep -qFx -- "$lcbase"; then
    return 0
  fi
  if [[ -n "$ignore_paths" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      [[ "$path" == $pattern ]] && return 0
    done <<<"$ignore_paths"
  fi
  return 1
}
