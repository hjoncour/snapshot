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

  --remove-all-ignored)
    remove_all_ignored
    ;;

  --remove-all-ignored-paths)
    remove_all_ignored_paths
    ;;

  --remove-all-ignored-files)
    remove_all_ignored_files
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

  --remove-all-types)
    remove_all_types
     ;;

  --add-default-types|add-default-types)
    add_default_types
    ;;
  *)
    echo "snapshot: unknown command '$cmd'." >&2
    echo "usage: snapshot [tree|code]"                                       >&2
    echo "                [--config]"                                        >&2
    echo "                [--ignore|--remove-ignore]"                        >&2
    echo "                [--remove-all-ignored|--remove-all-ignored-paths]" >&2
    echo "                [--remove-all-ignored-files]"                      >&2
    echo "                [--use-gitignore]"                                 >&2
    echo "                [--add-type|--remove-type|--remove-all-types]"     >&2
    echo "                [--copy] [--print] [--no-snapshot]"                >&2
    echo "                [--add-type|--remove-type|--remove-all-types|--add-default-types]" >&2
    exit 2
    ;;
esac
