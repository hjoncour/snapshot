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
    if command -v pbcopy >/dev/null 2>&1; then
      printf '%s\n' "$raw_dump" | pbcopy
      bytes=$(printf '%s\n' "$raw_dump" | wc -c)
      echo "snapshot: copied $bytes bytes to clipboard."
    else
      echo "snapshot: install 'pbcopy' first."
    fi
    printf '%s\n' "$raw_dump" | save_snapshot >/dev/null
    ;;

  ###########################################################################
  # ─────────────────────────── projects listing ──────────────────────────── #
  ###########################################################################
  projects|--projects)
    # Defaults
    want_details=false
    sort_dir="asc"
    sort_key="name"
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
        num=$(find "$d" -type f -name '*.snapshot' | wc -l | tr -d ' ')
        size_kb=$(du -sk "$d" | awk '{print $1}')
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
  # ─────────────────────── list snapshots for a project ─────────────────── #
  ###########################################################################
  list-snapshots|--list-snapshots)
    # Defaults
    want_details=false
    sort_dir="asc"
    sort_key="name"
    separators_override="__unset__"
    project_arg=""

    #######################################################################
    # Optional first positional token → explicit project name
    #######################################################################
    if [[ $# -gt 0 && ! "$1" =~ ^(details|--details|asc:|desc:|separators:on|separators:off)$ ]]; then
      project_arg="$1"; shift
    fi

    # Remaining positional options (order-agnostic)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        details|--details)          want_details=true ;;
        asc:*|desc:*)               IFS=':' read -r sort_dir sort_key <<<"$1" ;;
        separators:on)              separators_override="on"  ;;
        separators:off)             separators_override="off" ;;
        *) echo "snapshot: unknown --list-snapshots option '$1'." >&2; exit 2 ;;
      esac
      shift
    done

    #######################################################################
    # Detect project name when none supplied
    #   1) local config.json (project key)
    #   2) repository directory name         ← **new – before global cfg**
    #   3) global config (rare fallback)
    #######################################################################
    if [[ -z "$project_arg" ]]; then
      local_cfg="$git_root/config.json"
      if [[ -f "$local_cfg" ]]; then
        project_arg=$(jq -r '.project // empty' "$local_cfg")
      fi
      [[ -z "$project_arg" ]] && project_arg=$(basename "$git_root")
      [[ -z "$project_arg" ]] && project_arg=$(jq -r '.project // empty' "$global_cfg")
    fi

    snap_dir="$cfg_default_dir/$project_arg"
    [ -d "$snap_dir" ] || { echo "snapshot: no snapshots found for project '$project_arg'."; exit 0; }

    #######################################################################
    # Separator preference
    #######################################################################
    cfg_sep=$(jq -r '.settings.preferences.separators // "true"' "$global_cfg" 2>/dev/null || echo "true")
    if   [[ $separators_override == "on"  ]]; then use_sep=true
    elif [[ $separators_override == "off" ]]; then use_sep=false
    else                                           use_sep=$cfg_sep
    fi

    snapshots=()

    #######################################################################
    # Build list
    #######################################################################
    while IFS= read -r f; do
      bn=$(basename "$f")                 # full filename
      base="${bn%.snapshot}"              # strip extension

      size_kb=$(du -sk "$f" | awk '{print $1}')
      files=$(grep -c '^=====' "$f" || echo 0)

      epoch=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f")
      date_fmt=$(date -u -d "@$epoch" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
                 || date -u -r "$epoch" +'%Y-%m-%d %H:%M:%S')

      # derive branch & tags from filename
      IFS='_' read -r _ts branch rem <<<"$base"
      tags_part="${rem#*__}"
      [[ "$tags_part" != "$rem" ]] && tags="$tags_part" || tags="-"

      if $want_details; then
        snapshots+=( "$bn|$date_fmt|$tags|$size_kb|$files|$branch" )
      else
        snapshots+=( "$bn" )
      fi
    done < <(ls -1 "$snap_dir"/*.snapshot 2>/dev/null)

    #######################################################################
    # Sorting
    #######################################################################
    if $want_details; then
      case "$sort_key" in
        name)  field=1; sort_flags=""  ;;
        size)  field=4; sort_flags="-n";;
        date)  field=2; sort_flags=""  ;;
        *)     field=1; sort_flags=""  ;;
      esac
      sorted=$(
        printf '%s\n' "${snapshots[@]}" |
        sort -t'|' $sort_flags $( [[ $sort_dir == desc ]] && echo "-r" ) \
             -k"$field","$field"
      )

      ###################################################################
      # Pretty-print (dynamic widths)
      ###################################################################
      hdr_name="Snapshot"
      hdr_date="Created"
      hdr_tags="Tags"
      hdr_size="Size(KB)"
      hdr_files="Files"
      hdr_branch="Branch"

      max_name=${#hdr_name}; max_tags=${#hdr_tags}
      max_size=${#hdr_size}; max_files=${#hdr_files}; max_branch=${#hdr_branch}

      while IFS='|' read -r n _d t s f b; do
        (( ${#n}  > max_name  )) && max_name=${#n}
        (( ${#t}  > max_tags  )) && max_tags=${#t}
        (( ${#s}  > max_size  )) && max_size=${#s}
        (( ${#f}  > max_files )) && max_files=${#f}
        (( ${#b}  > max_branch)) && max_branch=${#b}
      done <<<"$sorted"

      dash() { printf '%*s' "$1" '' | tr ' ' '-'; }
      sep=$($use_sep && echo ' | ' || echo '  ')

      printf "%-${max_name}s${sep}%-19s${sep}%-${max_tags}s${sep}%${max_size}s${sep}%${max_files}s${sep}%-${max_branch}s\n" \
             "$hdr_name" "$hdr_date" "$hdr_tags" "$hdr_size" "$hdr_files" "$hdr_branch"
      printf "%-${max_name}s${sep}%-19s${sep}%-${max_tags}s${sep}%${max_size}s${sep}%${max_files}s${sep}%-${max_branch}s\n" \
             "$(dash "$max_name")" "$(dash 19)" "$(dash "$max_tags")" \
             "$(dash "$max_size")" "$(dash "$max_files")" "$(dash "$max_branch")"

      while IFS='|' read -r n d t s f b; do
        printf "%-${max_name}s${sep}%-19s${sep}%-${max_tags}s${sep}%${max_size}s${sep}%${max_files}s${sep}%-${max_branch}s\n" \
               "$n" "$d" "$t" "$s" "$f" "$b"
      done <<<"$sorted"
    else
      if [[ $sort_dir == desc ]]; then
        printf '%s\n' "${snapshots[@]}" | sort -r
      else
        printf '%s\n' "${snapshots[@]}" | sort
      fi
    fi
    ;;

  ###########################################################################
  # ─────────────────────── preference helpers ──────────────────────────── #
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

  #############################################################################
  # ─────────────────────── persist verbosity preference ─────────────────── #
  #############################################################################
  set-verbose:*|--set-verbose:*)
    val="${cmd#*:}"
    case "$val" in
      mute|minimal|normal|verbose|debug) ;;
      *)
        echo "snapshot: use set-verbose:mute|minimal|normal|verbose|debug" >&2
        exit 2
        ;;
    esac
    need_jq "--set-verbose"
    jq --arg v "$val" '
      (.settings             //= {}) |
      (.settings.preferences //= {}) |
      .settings.preferences.verbose = $v
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: preferences.verbose set to $val."
    ;;

  ###########################################################################
  # Other commands (config, ignore, …)
  ###########################################################################
  config|-c|--config)                     show_config              ;;
  ignore|-i|--ignore)                     add_ignores "$@"         ;;
  remove-ignore|--remove-ignore)          remove_ignores "$@"      ;;
  remove-all-ignored|--remove-all-ignored)            remove_all_ignored;;
  remove-all-ignored-paths|--remove-all-ignored-paths) remove_all_ignored_paths;;
  remove-all-ignored-files|--remove-all-ignored-files) remove_all_ignored_files;;
  use-gitignore|--use-gitignore)          use_gitignore            ;;
  add-type|--add-type)                    add_types "$@"           ;;
  remove-type|--remove-type)              remove_types "$@"        ;;
  remove-all-types|--remove-all-types)    remove_all_types         ;;
  add-default-types|--add-default-types)  add_default_types        ;;

  ###########################################################################
  # Default: no command → save snapshot & summarise based on verbosity
  ###########################################################################
  "")
    raw_dump=$(dump_code)
    # 1) save snapshot(s)
    saved_paths=$(printf '%s\n' "$raw_dump" | save_snapshot)

    # 2) optional clipboard copy
    if $do_copy; then
      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "$raw_dump" | pbcopy
        bytes=$(printf '%s\n' "$raw_dump" | wc -c)
        echo "snapshot: copied $bytes bytes to clipboard."
      else
        echo "snapshot: install 'pbcopy' first."
      fi
    fi

    # 3) verbosity-controlled summary
    case "$verbosity_override" in
      mute) ;;   # no output
      minimal|normal)
        last=$(printf '%s\n' "$saved_paths" | tail -n1)
        echo "[${last##*/}] created"
        ;;
      verbose|debug)
        sep_pref=$(jq -r '.settings.preferences.separators // "true"' "$global_cfg")
        [[ "$sep_pref" == "true" ]] && sep=' | ' || sep='  '

        hdr1="Snapshot" hdr2="Files" hdr3="Lines" hdr4="Size" hdr5="Location"
        max_name=${#hdr1} max_files=${#hdr2} max_lines=${#hdr3} max_size=${#hdr4}

        rows=""
        while IFS= read -r sfile; do
          name=$(basename "$sfile")
          files=$(grep -c '^=====' "$sfile" || echo 0)
          lines=$(wc -l < "$sfile" | tr -d ' ')
          size=$(du -h "$sfile" | awk '{print $1}')
          rows+="$name|$files|$lines|$size|$sfile"$'\n'

          (( ${#name}  > max_name  )) && max_name=${#name}
          (( ${#files} > max_files )) && max_files=${#files}
          (( ${#lines} > max_lines )) && max_lines=${#lines}
          (( ${#size}  > max_size  )) && max_size=${#size}
        done <<<"$saved_paths"

        dash() { printf '%*s' "$1" '' | tr ' ' '-'; }

        printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
               "$hdr1" "$hdr2" "$hdr3" "$hdr4" "$hdr5"
        printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
               "$(dash "$max_name")" "$(dash "$max_files")" "$(dash "$max_lines")" \
               "$(dash "$max_size")" "$(dash ${#hdr5})"

        printf '%s' "$rows" | while IFS='|' read -r n f l sz p; do
          printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
                 "$n" "$f" "$l" "$sz" "$p"
        done
        ;;
    esac

    # 4) optional full dump output
    $do_print && printf '\n%s\n' "$raw_dump"
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
  projects, --projects             list projects
  list-snapshots, --list-snapshots [PROJECT]  list saved snapshots
  set-separators:on|off            persist separator preference
  set-verbose:mute|minimal|normal|verbose|debug
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

list-snapshots options (order-agnostic):
  details / --details              add columns Size / Files / Date / …
  asc:KEY | desc:KEY               sort by name | size | date (asc default)
  separators:on|off                override separator preference

projects options (order-agnostic):
  details / --details
  asc:KEY | desc:KEY               sort by name | size | date
  separators:on|off

Flags:
  --name NAME …
  --tag TAG …
  --to DIR …
  --no-snapshot
  --print
  --copy
  --verbose:mute|minimal|normal|verbose|debug
EOF
    exit 2
    ;;
esac
