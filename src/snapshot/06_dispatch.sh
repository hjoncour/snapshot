###############################################################################
# 6. Dispatch
###############################################################################
cmd="${1:-code}"
case "$cmd" in
  tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: install 'tree' first."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  code)
    SNAPSHOT_FILE=$(dump_code | save_snapshot)

    $do_print && cat "$SNAPSHOT_FILE"
    if $do_copy; then
      command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: install 'pbcopy' first."; exit 1; }
      bytes=$(wc -c <"$SNAPSHOT_FILE")
      pbcopy <"$SNAPSHOT_FILE"
      echo "snapshot: copied $bytes bytes to clipboard."
    fi
    ;;

  --config|-c|config)
    show_config
    ;;

  --ignore|-i|ignore)
    shift
    add_ignores "$@"
    ;;

  --remove-ignore)
    shift
    remove_ignores "$@"
    ;;

  --use-gitignore)
    use_gitignore
    ;;

  --add-type|add-type)
    shift
    add_types "$@"
    ;;

  --remove-type|remove-type)
    shift
    remove_types "$@"
    ;;

  *)
    echo "snapshot: unknown command '$cmd'." >&2
    echo "usage: snapshot [tree|code|--config|--ignore|--remove-ignore|--use-gitignore] [--copy] [--print] [--no-snapshot] [--add-type] [--remove-type]" >&2
    exit 2
    ;;
esac
