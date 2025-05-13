# ─────────────────────────────────────────────────────────────────────────────
# 4-A. Built-in default extension list
# ─────────────────────────────────────────────────────────────────────────────
default_types='sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|yaml|yml|toml|ini|cfg|conf|env|xml|gradle|mk'


if jq -e '.settings | has("types_tracked")' "$global_cfg" >/dev/null 2>&1; then
  if [ "$(jq '.settings.types_tracked | length' "$global_cfg")" -eq 0 ]; then
    type_regex='___NO_MATCH___'          # honour an **empty** list ⇒ match nothing
  else
    type_regex=$(jq -r '.settings.types_tracked[]' "$global_cfg" | paste -sd '|' -)
  fi
 else
   type_regex="$default_types"
 fi

# pattern **must** exist before dump_code() is defined / invoked
exts='\.(('"$type_regex"'))$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'
