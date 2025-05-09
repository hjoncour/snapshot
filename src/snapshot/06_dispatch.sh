###############################################################################
# 6. Dispatch
###############################################################################
cmd="${1:-code}"
case "$cmd" in
  tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: error - install 'tree'."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  code)
    # generate dump, save to file, and capture the filename
    SNAPSHOT_FILE=$(dump_code | save_snapshot)

    # optionally print to stdout
    if [[ "$do_print" == true ]]; then
      cat "$SNAPSHOT_FILE"
    fi

    # optionally copy to clipboard
    if [[ "$do_copy" == true ]]; then
      command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: error - pbcopy not found."; exit 1; }
      bytes=$(wc -c < "$SNAPSHOT_FILE")
      pbcopy < "$SNAPSHOT_FILE"
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

  --add-type|add-type)
    shift
    add_types "$@"
    ;;

  --remove-type|remove-type)
    shift
    remove_types "$@"
    ;;

  *)
    echo "snapshot: error - unknown command '$cmd'" >&2
    echo "usage: snapshot [tree|--config|--ignore|--add-type|--remove-type] [--copy] [--print] [--no-snapshot]" >&2
    exit 2
    ;;
esac
