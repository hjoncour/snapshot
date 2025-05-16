#!/usr/bin/env bash
###############################################################################
# 06_dispatch.sh - Dispatch
###############################################################################
set -euo pipefail

# Grab the primary command (or empty if none)
cmd="${1:-}"; shift || true

case "$cmd" in
  #############################################################################
  # ───────────────────────────────── File-tree / Dumps ────────────────────── #
  #############################################################################
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

  #############################################################################
  # ─────────────────────────── projects listing ──────────────────────────── #
  #############################################################################
  projects|--projects)
    ###############################################################
    # 0. Parse positional options
    ###############################################################
    want_details=false
    sort_dir="asc"
    sort_key="name"
    separators_override="__unset__"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        details|--details)   want_details=true ;;
        asc:*|desc:*)
          IFS=':' read -r sort_dir sort_key <<<"$1"
          ;;
        separators:on)  separators_override="on"  ;;
        separators:off) separators_override="off" ;;
        *) echo "snapshot: unknown --projects option '$1'." >&2; exit 2 ;;
      esac
      shift
    done

    ###############################################################
    # 1. Figure out column-separator preference
    ###############################################################
    cfg_sep=$(jq -r '.settings.preferences.separators // empty' \
                "$global_cfg" 2>/dev/null || true)
    [[ "$cfg_sep" == "true" || "$cfg_sep" == "false" ]] || cfg_sep="true"

    if   [[ $separators_override == "on"  ]]; then use_sep=true
    elif [[ $separators_override == "off" ]]; then use_sep=false
    else                                         use_sep=$cfg_sep
    fi

    sep=$($use_sep && echo ' | ' || echo '   ')

    ###############################################################
    # 2. Gather projects
    ###############################################################
    base_dir="$cfg_default_dir"
    [ -d "$base_dir" ] || { echo "snapshot: no projects found."; exit 0; }

    projects=()

    #########################################################################
    # Build list
    #########################################################################
    while IFS= read -r d; do
      proj=$(basename "$d")
      if $want_details; then
        num=$(find "$d" -type f -name '*.snapshot' | wc -l | tr -d ' ')
        size_kb=$(du -sk "$d" | awk '{print $1}')

        # Pick newest *.snapshot (if any) and get its mtime (epoch)
        latest_file=$(find "$d" -type f -name '*.snapshot' -printf '%T@ %p\n' \
                      | sort -nr | head -n1 | cut -d' ' -f2-)

        if [[ -n "$latest_file" ]]; then
          # ── cross-platform epoch extraction ──
          if epoch=$(stat -c '%Y' "$latest_file" 2>/dev/null); then
            :                               # GNU coreutils
          else
            epoch=$(stat -f '%m' "$latest_file")   # BSD / macOS
          fi

          # ── cross-platform ISO timestamp ──
          if latest_fmt=$(date -u -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null); then
            :                               # GNU date
          else
            latest_fmt=$(date -u -r "$epoch" '+%Y-%m-%d %H:%M:%S')  # BSD date
          fi
        else
          epoch=0
          latest_fmt='-'
        fi
        projects+=( "$proj|$num|$size_kb|$epoch|$latest_fmt" )
      else
        projects+=( "$proj" )
      fi
    done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d | sort)

    ###############################################################
    # 3. Sorting
    ###############################################################
    if $want_details; then
      case "$sort_key" in
        name) field=1 sort_flags=''  ;;
        size) field=3 sort_flags='-n';;
        date) field=4 sort_flags='-n';;
        *)    field=1 sort_flags=''  ;;
      esac

      sorted=$(printf '%s\n' "${projects[@]}" |
               sort -t'|' $sort_flags $( [[ $sort_dir == desc ]] && echo -r ) \
               -k"$field","$field")

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
      printf '%s\n' "${projects[@]}" | ( [ "$sort_dir" = desc ] && sort -r || sort )
    fi
    ;;

  #############################################################################
  # ─────────────────────── Persist separators preference ─────────────────── #
  #############################################################################
  set-separators:*|--set-separators:*)
    val="${cmd#*:}"
    case "$val" in
      on)  bool=true  ;;
      off) bool=false ;;
      *)   echo "snapshot: use set-separators:on|off"; exit 2 ;;
    esac
    need_jq "--set-separators"
    jq --argjson b "$bool" '
      (.settings              //= {}) |
      (.settings.preferences  //= {}) |
      .settings.preferences.separators = $b
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: preferences.separators set to $bool."
    ;;

  #############################################################################
  # ───────────────────────────── Other helpers ───────────────────────────── #
  #############################################################################
  config|-c|--config)                         show_config                     ;;
  ignore|-i|--ignore)                         add_ignores "$@"               ;;
  remove-ignore|--remove-ignore)              remove_ignores "$@"            ;;
  remove-all-ignored|--remove-all-ignored)    remove_all_ignored             ;;
  remove-all-ignored-paths|--remove-all-ignored-paths)
                                              remove_all_ignored_paths       ;;
  remove-all-ignored-files|--remove-all-ignored-files)
                                              remove_all_ignored_files       ;;
  use-gitignore|--use-gitignore)              use_gitignore                  ;;
  add-type|--add-type)                        add_types "$@"                 ;;
  remove-type|--remove-type)                  remove_types "$@"              ;;
  remove-all-types|--remove-all-types)        remove_all_types               ;;
  add-default-types|--add-default-types)      add_default_types              ;;

  #############################################################################
  # ─────────────────────────── default dump flow ─────────────────────────── #
  #############################################################################
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
    ! $no_snapshot && printf '%s\n' "$raw_dump" | save_snapshot >/dev/null
    ;;

  #############################################################################
  # ───────────────────────────── Unknown command ─────────────────────────── #
  #############################################################################
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