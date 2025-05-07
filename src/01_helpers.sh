###############################################################################
# 1. Helpers  (verbatim copy)
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
