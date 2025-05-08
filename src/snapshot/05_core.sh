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
# Saving to ~/Library/Application Support/snapshot/<project>/<epoch>_<branch>_<hash>
###############################################################################
save_snapshot() {
  # skip if user passed --no-snapshot
  [ "$no_snapshot" = true ] && return 0

  # derive project name
  project=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$project" ] && project="$(basename "$git_root")"

  # timestamp, branch, commit
  epoch=$(date +%s)
  # replace any “/” in the branch name with “_” so it doesn’t split the path
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}

  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  # make the target directory (quotes handle the space in “Application Support”)
  out_dir="$cfg_default_dir/$project"
  mkdir -p "$out_dir"

  # build the full filename
  out_file="$out_dir/${epoch}_${branch}_${commit}.snapshot"

  # **this** line writes stdin into your file (must be quoted!)
  cat > "$out_file"

  # let the user know
  echo "snapshot: saved dump to $out_file" >&2
}
