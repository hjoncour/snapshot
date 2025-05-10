###############################################################################
# 1. Helpers
###############################################################################
need_jq() {
  command -v jq >/dev/null 2>&1 && return
  echo "snapshot: error - '$1' requires jq (not found in PATH)." >&2
  exit 1
}

show_config() {
  # you can also do: cat "$global_cfg"
  jq . "$global_cfg"
}

add_ignores() {
  need_jq "--ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --ignore needs arguments." >&2; exit 2; }
  for item in "$@"; do
    if [[ "$item" == */* || "$item" == *'*'* || "$item" == *'?'* || "$item" == .* ]]; then
      jq --arg p "$item" \
         '.ignore_path = ((.ignore_path // []) + [$p] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      echo "snapshot: added '$item' to ignore_path."
    else
      jq --arg f "$item" \
         '.ignore_file = ((.ignore_file // []) + [$f] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      echo "snapshot: added '$item' to ignore_file."
    fi
  done
}

remove_ignores() {
  need_jq "--remove"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --remove needs arguments." >&2; exit 2; }
  for item in "$@"; do
    jq --arg x "$item" '
      .ignore_file = ((.ignore_file // []) | map(select(. != $x))) |
      .ignore_path = ((.ignore_path // []) | map(select(. != $x)))
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: removed '$item' from ignore_file and ignore_path."
  done
}

add_types() {
  need_jq "--add-type"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --add-type needs arguments." >&2; exit 2; }
  for t in "$@"; do
    jq --arg ext "$t" \
       '.settings.types_tracked = ((.settings.types_tracked // []) + [$ext] | unique)' \
       "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: added '$t' to settings.types_tracked."
  done
}

remove_types() {
  need_jq "--remove-type"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --remove-type needs arguments." >&2; exit 2; }
  for t in "$@"; do
    jq --arg ext "$t" \
       '.settings.types_tracked = ((.settings.types_tracked // []) | map(select(. != $ext)))' \
       "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: removed '$t' from settings.types_tracked."
  done
}
