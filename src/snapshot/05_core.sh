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
