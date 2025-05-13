###############################################################################
# 06_dispatch.sh – Dispatch
###############################################################################
# No explicit "code" subcommand: running `snapshot` with no argument
# does the code snapshot (dump+save), with optional --print/--copy flags.

# Grab the primary command (or empty if none)
cmd="${1:-}"; shift || true

case "$cmd" in
  tree|--tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: install 'tree' first."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  print|--print)
    SNAPSHOT_FILE=$(dump_code | save_snapshot)
    cat "$SNAPSHOT_FILE"
    ;;

  copy|--copy)
    SNAPSHOT_FILE=$(dump_code | save_snapshot)
    command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: install 'pbcopy' first."; exit 1; }
    bytes=$(wc -c <"$SNAPSHOT_FILE")
    pbcopy <"$SNAPSHOT_FILE"
    echo "snapshot: copied $bytes bytes to clipboard."
    ;;

  config|-c|--config)
    show_config
    ;;

  ignore|-i|--ignore)
    add_ignores "$@"
    ;;

  remove-ignore|--remove-ignore)
    remove_ignores "$@"
    ;;

  remove-all-ignored|--remove-all-ignored)
    remove_all_ignored
    ;;

  remove-all-ignored-paths|--remove-all-ignored-paths)
    remove_all_ignored_paths
    ;;

  remove-all-ignored-files|--remove-all-ignored-files)
    remove_all_ignored_files
    ;;

  use-gitignore|--use-gitignore)
    use_gitignore
    ;;

  add-type|--add-type)
    add_types "$@"
    ;;

  remove-type|--remove-type)
    remove_types "$@"
    ;;

  remove-all-types|--remove-all-types)
    remove_all_types
    ;;

  add-default-types|--add-default-types)
    add_default_types
    ;;

  "")
    # default: dump & save, then handle --print/--copy
    SNAPSHOT_FILE=$(dump_code | save_snapshot)
    $do_print && cat "$SNAPSHOT_FILE"
    if $do_copy; then
      command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: install 'pbcopy' first."; exit 1; }
      bytes=$(wc -c <"$SNAPSHOT_FILE")
      pbcopy <"$SNAPSHOT_FILE"
      echo "snapshot: copied $bytes bytes to clipboard."
    fi
    ;;

  *)
    echo "snapshot: unknown command '$cmd'." >&2
    cat <<EOF >&2
usage: snapshot [COMMAND]

Commands (both bare and --prefixed forms are supported):
  tree, --tree
  print, --print
  copy, --copy
  config, -c, --config
  ignore, -i, --ignore
  remove-ignore, --remove-ignore
  remove-all-ignored, --remove-all-ignored
  remove-all-ignored-paths, --remove-all-ignored-paths
  remove-all-ignored-files, --remove-all-ignored-files
  use-gitignore, --use-gitignore
  add-type, --add-type
  remove-type, --remove-type
  remove-all-types, --remove-all-types
  add-default-types, --add-default-types

Flags:
  --no-snapshot    skip saving snapshot file (dump only)
EOF
    exit 2
    ;;
esac
