###############################################################################
# 4. Build the extension‑matching regex
###############################################################################
#
# Priority:
#   1. If the global config provides settings.types_tracked → use that list
#   2. Otherwise fall back to the built‑in default (exactly the old list)
#

default_types='sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|yaml|yml|toml|ini|cfg|conf|env|xml|gradle|mk'

cfg_types=$(jq -r '.settings.types_tracked[]?' "$global_cfg" 2>/dev/null | paste -sd '|' -)
[ -n "$cfg_types" ] && type_regex="$cfg_types" || type_regex="$default_types"

# Assemble the final pattern (keep special‑case filenames exactly as before)
exts='\.('"$type_regex"')$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'
