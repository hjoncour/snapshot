###############################################################################
# 4. Build extension-matching regex
###############################################################################

default_types='sh|bash|zsh|ksh|c|cc|cpp|h|hpp|java|kt|go|rs|py|js|ts|jsx|tsx|rb|php|pl|swift|scala|dart|cs|sql|html|css|scss|md|json|yaml|yml|toml|ini|cfg|conf|env|xml|gradle|mk'

cfg_types=$(jq -r '.settings.types_tracked[]?' "$global_cfg" 2>/dev/null | paste -sd '|' -)
type_regex="${cfg_types:-$default_types}"

# Assemble the final pattern (keep special‑case filenames exactly as before)
exts='\.('"$type_regex"')$|(^|/)Dockerfile$|(^|/)docker-compose\.ya?ml$|(^|/)Makefile$'
