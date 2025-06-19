###############################################################################
# 3. Build ignore lists
###############################################################################
ignore_files=$(jq -r '.ignore_file[]?' "$global_cfg" 2>/dev/null || true)
ignore_files_lc=$(printf '%s\n' $ignore_files | tr '[:upper:]' '[:lower:]')
ignore_paths=$(jq -r '.ignore_path[]?' "$global_cfg" 2>/dev/null || true)

###############################################################################
# 3-A. Optional test-file ignore list (activated by --ignore-test)
###############################################################################
if $ignore_test; then
  builtin_test_paths=$'test/**\ntests/**\n**/__tests__/**\n**/*.test.*\n**/*_test.*'
  user_test_paths=$(jq -r '.settings.test_paths[]?' "$global_cfg" 2>/dev/null || true)
  test_paths=$(printf '%s\n%s' "$builtin_test_paths" "$user_test_paths" | awk '!a[$0]++')
  ignore_paths=$(printf '%s\n%s' "$ignore_paths" "$test_paths" | awk '!a[$0]++')
fi

###############################################################################
# 3-B. Helper functions
###############################################################################
shopt -s extglob globstar 2>/dev/null || true

is_ignored() {
  local path="$1" base lcbase
  base="${path##*/}"
  lcbase=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')

  # 1) literal-filename matches (case-insensitive)
  if [[ -n "$ignore_files_lc" ]] \
     && printf '%s\n' $ignore_files_lc | grep -qFx -- "$lcbase"; then
    return 0
  fi

  # 2) glob-style path patterns  +  directory prefixes
  if [[ -n "$ignore_paths" ]]; then
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue

      # normalise: treat “dir” and “dir/” the same
      local p="${pattern%/}"

      # a) exact glob match (existing behaviour)
      [[ "$path" == $pattern ]] && return 0

      # b) recursive directory match – ignore everything **under** the listed path
      #    e.g.  pattern "build/static"  hides  "build/static/..."  at any depth
      if [[ "$path" == "$p"/* ]]; then
        return 0
      fi
    done <<<"$ignore_paths"
  fi
  return 1
}
