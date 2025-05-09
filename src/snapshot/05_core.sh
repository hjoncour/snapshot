###############################################################################
# 5. Core dumping routines + snapshot-to-file
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
  [ "$no_snapshot" = true ] && return 0

  project=$(jq -r '.project // empty' "$global_cfg")
  [ -z "$project" ] && project="$(basename "$git_root")"

  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  out_dir="$cfg_default_dir/$project"
  mkdir -p "$out_dir"
  out_file="$out_dir/${epoch}_${branch}_${commit}.snapshot"

  # write the dump into the file
  cat > "$out_file"
  # notify user on stderr
  echo "snapshot: saved dump to $out_file" >&2
  # echo the filename on stdout so the dispatcher can capture it
  echo "$out_file"
}
