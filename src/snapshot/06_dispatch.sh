#!/usr/bin/env bash
###############################################################################
# 06_dispatch.sh - Dispatch
###############################################################################

# Grab the primary command (or empty if none)
cmd="${1:-}"; shift || true

case "$cmd" in
  tree|--tree)
    command -v tree >/dev/null 2>&1 || { echo "snapshot: install 'tree' first."; exit 1; }
    filtered_for_tree | tree --fromfile
    ;;

  print|--print)
    dump_code | save_snapshot >/dev/null
    dump_code | cat
    ;;

  copy|--copy)
    raw_dump=$(dump_code)
    printf '%s\n' "$raw_dump" | pbcopy
    bytes=$(printf '%s\n' "$raw_dump" | wc -c)
    echo "snapshot: copied $bytes bytes to clipboard."
    printf '%s\n' "$raw_dump" | save_snapshot >/dev/null
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
    #
    # no command: default to copying/printing first, then saving
    #
    raw_dump=$(dump_code)

    if $do_copy; then
      printf '%s\n' "$raw_dump" | pbcopy
      bytes=$(printf '%s\n' "$raw_dump" | wc -c)
      echo "snapshot: copied $bytes bytes to clipboard."
    fi

    if $do_print; then
      printf '%s\n' "$raw_dump"
    fi

    if ! $no_snapshot; then
      printf '%s\n' "$raw_dump" | save_snapshot >/dev/null
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
  --name N1 [N2 …]   name one or more snapshots (writes N1.snapshot etc)
  --no-snapshot      skip saving snapshot file(s) (dump only)
  --print            print the dump to stdout
  --copy             copy the dump to your clipboard
EOF
    exit 2
    ;;
esac
