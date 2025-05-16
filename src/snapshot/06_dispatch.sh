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

  projects|--projects)
    ############################################################################
    # List projects stored under:
    #   $HOME/Library/Application Support/snapshot/<project>
    #
    # Options (order-agnostic):
    #   details              – show columns: snapshots, size, latest
    #   asc:KEY / desc:KEY   – sort direction (default asc)
    #                         where KEY is  name | size | date
    #
    # Examples:
    #   snapshot --projects                       # simple list
    #   snapshot projects details                 # detailed, default sorting
    #   snapshot --projects details desc:size     # detailed, largest first
    #   snapshot --projects asc:date              # newest first (no extra cols)
    ############################################################################
    want_details=false
    sort_dir="asc"
    sort_key="name"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        details)                      want_details=true ;;
        asc:*|desc:*)                 IFS=':' read -r sort_dir sort_key <<<"$1" ;;
        *) echo "snapshot: unknown --projects option '$1'." >&2; exit 2 ;;
      esac
      shift
    done

    base_dir="$cfg_default_dir"
    [ -d "$base_dir" ] || { echo "snapshot: no projects found ($base_dir empty)."; exit 0; }

    projects=()
    while IFS= read -r d; do
      proj=$(basename "$d")
      if $want_details; then
        num=$(find "$d" -type f -name '*.snapshot' | wc -l | tr -d ' ')
        size_kb=$(du -sk "$d" | awk '{print $1}')
        latest_file=$(ls -1t "$d"/*.snapshot 2>/dev/null | head -n 1 || true)
        if [[ -n "$latest_file" ]]; then
          epoch=$(stat -f "%m" "$latest_file" 2>/dev/null || stat -c "%Y" "$latest_file")
          latest_fmt=$(date -u -d "@$epoch" +'%Y-%m-%d %H:%M:%S' 2>/dev/null || date -u -r "$epoch" +'%Y-%m-%d %H:%M:%S')
        else
          epoch=0
          latest_fmt="-"
        fi
        projects+=( "$proj|$num|$size_kb|$epoch|$latest_fmt" )
      else
        projects+=( "$proj" )
      fi
    done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d | sort)

    ###########################################################################
    # Sorting
    ###########################################################################
    if $want_details; then
      case "$sort_key" in
        name) field=1 sort_flags=""   ;;
        size) field=3 sort_flags="-n" ;;
        date) field=4 sort_flags="-n" ;;
        *)    field=1 sort_flags=""   ;;
      esac
      sorted=$(printf '%s\n' "${projects[@]}" |
               sort -t'|' $sort_flags -k"$field","$field"$( [[ $sort_dir == desc ]] && echo "r" ))

      #########################################################################
      # Dynamically size the columns for perfect alignment
      #########################################################################
      header_name="Project"; header_num="Snapshots"; header_size="Size(KB)"; header_latest="Latest"
      max_name=${#header_name}; max_num=${#header_num}; max_size=${#header_size}

      # one pass to capture max widths
      while IFS='|' read -r n num size _epoch _latest; do
        (( ${#n}   > max_name )) && max_name=${#n}
        (( ${#num} > max_num  )) && max_num=${#num}
        (( ${#size}> max_size )) && max_size=${#size}
      done < <(printf '%s\n' "$sorted")

      dash() { printf '%*s' "$1" '' | tr ' ' '-'; }

      printf "%-${max_name}s %${max_num}s %${max_size}s %s\n" \
             "$header_name" "$header_num" "$header_size" "$header_latest"
      printf "%-${max_name}s %${max_num}s %${max_size}s %s\n" \
             "$(dash "$max_name")" "$(dash "$max_num")" "$(dash "$max_size")" "$(dash ${#header_latest})"

      printf '%s\n' "$sorted" |
      while IFS='|' read -r name num size _epoch latest; do
        printf "%-${max_name}s %${max_num}s %${max_size}s %s\n" \
               "$name" "$num" "$size" "$latest"
      done
    else
      # simple list (names only)
      if [ "$sort_dir" = "desc" ]; then
        printf '%s\n' "${projects[@]}" | sort -r
      else
        printf '%s\n' "${projects[@]}" | sort
      fi
    fi
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
      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "$raw_dump" | pbcopy
        bytes=$(printf '%s\n' "$raw_dump" | wc -c)
        echo "snapshot: copied $bytes bytes to clipboard."
      else
        echo "snapshot: install 'pbcopy' first."
      fi
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
  projects, --projects      (list projects; see details above)
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
  --tag  T1 [T2 …]   tag snapshot(s); becomes “…__T1_T2.snapshot”
  --to   DIR [DIR …] save snapshot(s) to extra DIRs in addition to the default
  --no-snapshot      skip saving snapshot file(s) (dump only)
  --print            print the dump to stdout
  --copy             copy the dump to your clipboard
EOF
    exit 2
    ;;
esac
