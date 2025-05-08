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
    dump_code | tee >(save_snapshot)
    ;;

  copy)
    command -v pbcopy >/dev/null 2>&1 || { echo "snapshot: error - pbcopy not found."; exit 1; }
    bytes=$(dump_code | tee >(save_snapshot) | tee >(wc -c) | pbcopy | tail -1)
    echo "snapshot: copied $bytes bytes to clipboard."
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
    echo "usage: snapshot [tree|code|copy|--config|--ignore|--add-type|--remove-type]" >&2
    exit 2
    ;;
esac
