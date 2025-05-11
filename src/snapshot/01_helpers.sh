###############################################################################
# 1. Helpers
###############################################################################
need_jq() {
  command -v jq >/dev/null 2>&1 && return
  echo "snapshot: error - '$1' requires jq (not found in PATH)." >&2
  exit 1
}

show_config() {
  # pretty-print everything, but inline our three arrays
  local proj version owner desc types ignore_files ignore_paths
  proj=$(jq -r '.project // ""'       "$global_cfg")
  version=$(jq -r '.version // ""'     "$global_cfg")
  owner=$(jq -r '.owner // ""'         "$global_cfg")
  desc=$(jq -r '.description|@json'    "$global_cfg")
  types=$(jq -r '.settings.types_tracked // [] | map(@json) | join(", ")' "$global_cfg")
  ignore_files=$(jq -r '.ignore_file   // [] | map(@json) | join(", ")' "$global_cfg")
  ignore_paths=$(jq -r '.ignore_path   // [] | map(@json) | join(", ")' "$global_cfg")

  cat <<EOF
{
  "project": "$proj",
  "version": "$version",
  "owner": "$owner",
  "description": $desc,
  "settings": {
    "types_tracked": [${types}]
  },
  "ignore_file": [${ignore_files}],
  "ignore_path": [${ignore_paths}]
}
EOF
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
  need_jq "--remove-ignore"
  [ "$#" -gt 0 ] || { echo "snapshot: error - --remove-ignore needs arguments." >&2; exit 2; }
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

use_gitignore() {
  # read .gitignore and add each pattern
  [ -f .gitignore ] || { echo "snapshot: .gitignore not found." >&2; exit 1; }
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == */ || "$line" == */* || "$line" == *'*'* || "$line" == *'?'* ]]; then
      jq --arg p "$line" \
         '.ignore_path = ((.ignore_path // []) + [$p] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      echo "snapshot: added '$line' to ignore_path."
    else
      jq --arg f "$line" \
         '.ignore_file = ((.ignore_file // []) + [$f] | unique)' \
         "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
      echo "snapshot: added '$line' to ignore_file."
    fi
  done < .gitignore
}
