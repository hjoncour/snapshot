#!/usr/bin/env bash
###############################################################################
# 06_dispatch.sh – Dispatch
###############################################################################

# Grab the primary command (or empty if none)
cmd="${1:-}"; shift || true

case "$cmd" in
  ###########################################################################
  # Basic helpers
  ###########################################################################
  tree|--tree)
    command -v tree >/dev/null 2>&1 || {
      echo "snapshot: install 'tree' first."; exit 1; }
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

  ###########################################################################
  # ─────────────────────────── projects listing ──────────────────────────── #
  ###########################################################################
  projects|--projects)
    # Defaults
    want_details=false
    sort_dir="asc"      # asc | desc
    sort_key="name"     # name | size | date
    separators_override="__unset__"

    # Parse positional options (order-agnostic)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        details|--details)          want_details=true ;;
        asc:*|desc:*)               IFS=':' read -r sort_dir sort_key <<<"$1" ;;
        separators:on)              separators_override="on"  ;;
        separators:off)             separators_override="off" ;;
        *) echo "snapshot: unknown --projects option '$1'." >&2; exit 2 ;;
      esac
      shift
    done

    #########################################################################
    # Determine final separator preference
    #########################################################################
    cfg_sep=$(jq -r '.settings.preferences.separators // "true"' \
                 "$global_cfg" 2>/dev/null || echo "true")

    if   [[ $separators_override == "on"  ]]; then use_sep=true
    elif [[ $separators_override == "off" ]]; then use_sep=false
    else                                           use_sep=$cfg_sep
    fi

    base_dir="$cfg_default_dir"
    [ -d "$base_dir" ] || {
      echo "snapshot: no projects found ($base_dir empty)."; exit 0; }

    projects=()

    #########################################################################
    # Build list
    #########################################################################
    while IFS= read -r d; do
      proj=$(basename "$d")

      if $want_details; then
        # How many snapshot files?
        num=$(find "$d" -type f -name '*.snapshot' | wc -l | tr -d ' ')

        # Folder size (KiB)
        size_kb=$(du -sk "$d" | awk '{print $1}')

        # Newest snapshot file (if any)
        latest_file=$(ls -1t "$d"/*.snapshot 2>/dev/null | head -n1 || true)
        if [[ -n "$latest_file" ]]; then
          epoch=$(stat -f "%m" "$latest_file" 2>/dev/null \
                  || stat -c "%Y" "$latest_file")
          latest_fmt=$(date -u -d "@$epoch" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
                       || date -u -r "$epoch" +'%Y-%m-%d %H:%M:%S')
        else
          epoch=0
          latest_fmt="-"
        fi
        projects+=( "$proj|$num|$size_kb|$epoch|$latest_fmt" )
      else
        projects+=( "$proj" )
      fi
    done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d | sort)

    #########################################################################
    # Sorting
    #########################################################################
    if $want_details; then
      case "$sort_key" in
        name) field=1; sort_flags=""  ;;
        size) field=3; sort_flags="-n";;
        date) field=4; sort_flags="-n";;
        *)    field=1; sort_flags=""  ;;
      esac
      sorted=$(
        printf '%s\n' "${projects[@]}" |
        sort -t'|' $sort_flags $( [[ $sort_dir == desc ]] && echo "-r" ) \
             -k"$field","$field"
      )

      #######################################################################
      # Pretty-print with dynamic column widths
      #######################################################################
      header_name="Project"
      header_num="Snapshots"
      header_size="Size(KB)"
      header_latest="Latest"

      max_name=${#header_name}
      max_num=${#header_num}
      max_size=${#header_size}

      while IFS='|' read -r n num size _e _l; do
        (( ${#n}   > max_name )) && max_name=${#n}
        (( ${#num} > max_num  )) && max_num=${#num}
        (( ${#size}> max_size )) && max_size=${#size}
      done <<<"$sorted"

      dash() { printf '%*s' "$1" '' | tr ' ' '-'; }

      if [[ "$use_sep" == true ]]; then
        sep=' | '
      else
        sep='  '
      fi

      printf "%-${max_name}s${sep}%${max_num}s${sep}%${max_size}s${sep}%s\n" \
             "$header_name" "$header_num" "$header_size" "$header_latest"
      printf "%-${max_name}s${sep}%${max_num}s${sep}%${max_size}s${sep}%s\n" \
             "$(dash "$max_name")" "$(dash "$max_num")" \
             "$(dash "$max_size")" "$(dash ${#header_latest})"

      while IFS='|' read -r name num size _e latest; do
        printf "%-${max_name}s${sep}%${max_num}s${sep}%${max_size}s${sep}%s\n" \
               "$name" "$num" "$size" "$latest"
      done <<<"$sorted"
    else
      if [[ $sort_dir == desc ]]; then
        printf '%s\n' "${projects[@]}" | sort -r
      else
        printf '%s\n' "${projects[@]}" | sort
      fi
    fi
    ;;

  ###########################################################################
  # ───────────────── persist separators preference ──────────────────────── #
  ###########################################################################
  set-separators:*|--set-separators:*)
    val="${cmd#*:}"
    case "$val" in
      on)  bool=true  ;;
      off) bool=false ;;
      *)   echo "snapshot: use set-separators:on|off"; exit 2 ;;
    esac
    need_jq "--set-separators"
    jq --argjson b "$bool" '
      (.settings             //= {}) |
      (.settings.preferences //= {}) |
      .settings.preferences.separators = $b
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: preferences.separators set to $bool."
    ;;

  ###########################################################################
  # All the other existing commands (config, ignore, …) remain unchanged
  ###########################################################################
  config|-c|--config)                     show_config              ;;
  ignore|-i|--ignore)                     add_ignores "$@"         ;;
  remove-ignore|--remove-ignore)          remove_ignores "$@"      ;;
  remove-all-ignored|--remove-all-ignored)            remove_all_ignored      ;;
  remove-all-ignored-paths|--remove-all-ignored-paths) remove_all_ignored_paths;;
  remove-all-ignored-files|--remove-all-ignored-files) remove_all_ignored_files;;
  use-gitignore|--use-gitignore)          use_gitignore            ;;
  add-type|--add-type)                    add_types "$@"           ;;
  remove-type|--remove-type)              remove_types "$@"        ;;
  remove-all-types|--remove-all-types)    remove_all_types         ;;
  add-default-types|--add-default-types)  add_default_types        ;;

  ###########################################################################
  # Default: generate a snapshot dump / copy / print
  ###########################################################################
  "")
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

    $do_print && printf '%s\n' "$raw_dump"

    if ! $no_snapshot; then
      printf '%s\n' "$raw_dump" | save_snapshot >/dev/null
    fi
    ;;

  ###########################################################################
  # Unknown command
  ###########################################################################
  *)
    echo "snapshot: unknown command '$cmd'." >&2
    cat <<EOF >&2
usage: snapshot [COMMAND]

Commands:
  tree, --tree
  print, --print
  copy, --copy
  projects, --projects          list projects (options below)
  set-separators:on|off         persist separator preference
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

projects options (order-agnostic):
  details / --details           add Snapshots / Size / Latest columns
  asc:KEY | desc:KEY            sort by name | size | date   (asc default)
  separators:on|off             override column separators

Flags:
  --name NAME …                 name one or more snapshots
  --tag  TAG  …                 tag snapshot(s)
  --to   DIR  …                 extra destination(s)
  --no-snapshot                 skip saving snapshot file(s)
  --print                       print the dump to stdout
  --copy                        copy the dump to your clipboard
EOF
    exit 2
    ;;
esac
