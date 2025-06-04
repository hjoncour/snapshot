#!/usr/bin/env bash
###############################################################################
# 06_dispatch.sh – Dispatch
###############################################################################

# Grab the primary command (or empty if none)
cmd="${1:-}"; shift || true

###############################################################################
# SECOND-PASS GLOBAL FLAGS  (those written *after* the command)
# -----------------------------------------------------------------------------
# Mirrors the first-pass in 00_preamble.sh so users may place flags either
# before *or* after the command word.
###############################################################################
while [[ "${1:-}" =~ ^-- ]]; do
  case "$1" in
    --no-snapshot)      no_snapshot=true;  shift ;;
    --copy)             do_copy=true;      shift ;;
    --print)            do_print=true;     shift ;;
    --ignore-test)      ignore_test=true;  shift ;;

    --name)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        custom_names+=( "$1" ); shift
      done ;;
    --name=*)           custom_names+=( "${1#--name=}" ); shift ;;

    --tag)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        tags+=( "$1" ); shift
      done ;;
    --tag=*)            tags+=( "${1#--tag=}" ); shift ;;

    --to)
      shift
      while [[ "${1:-}" && ! "${1}" =~ ^-- ]]; do
        dest_dirs+=( "$1" ); shift
      done ;;
    --to=*)             dest_dirs+=( "${1#--to=}" ); shift ;;

    --verbose:*)
      verbosity_override="${1#--verbose:}"
      case "$verbosity_override" in
        mute|minimal|normal|verbose|debug) ;;
        *) echo "snapshot: use --verbose:mute|minimal|normal|verbose|debug" >&2
           exit 2 ;;
      esac
      shift ;;
    *) break ;;
  esac
done

###############################################################################
# APPLY TEST IGNORES (needed when --ignore-test was given *after* the command)
###############################################################################
if $ignore_test && [[ -z "${_IGN_APPLIED:-}" ]]; then
  #  built-in patterns
  builtin_test_paths=$'test/**\ntests/**\n**/__tests__/**\n**/*.test.*\n**/*_test.*'
  #  user-configured extra patterns
  user_test_paths=$(jq -r '.settings.test_paths[]?' "$global_cfg" 2>/dev/null || true)
  #  merge & dedupe
  test_paths=$(printf '%s\n%s' "$builtin_test_paths" "$user_test_paths" | awk '!a[$0]++')
  ignore_paths=$(printf '%s\n%s' "$ignore_paths" "$test_paths" | awk '!a[$0]++')
  _IGN_APPLIED=1               # sentinel so we do it only once
fi

###############################################################################
# HELPER: self-update (`snapshot update`)
###############################################################################
update_snapshot() {
  command -v git >/dev/null 2>&1 || {
    echo "snapshot: 'git' is required for update (not found)." >&2; exit 1; }

  # 1) $SNAPSHOT_UPDATE_URL   2) config → .update_url   3) default GitHub repo
  local repo_url
  repo_url="${SNAPSHOT_UPDATE_URL:-$(jq -r '.update_url // empty' "$global_cfg")}"
  repo_url="${repo_url:-https://github.com/hjoncour/snapshot.git}"

  echo "snapshot: updating from $repo_url …"

  # Hidden temp dir – lives on the same filesystem for fast copies; cleaned on EXIT
  local tmpdir
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/.snapshot_update.XXXXXX")
  trap 'rm -rf "$tmpdir"' EXIT

  if ! git clone --quiet --depth 1 "$repo_url" "$tmpdir"; then
    echo "snapshot: git clone failed." >&2; exit 1
  fi

  if ! (cd "$tmpdir" && bash install_snapshot.sh >/dev/null); then
    echo "snapshot: install script failed." >&2; exit 1
  fi

  echo "snapshot: update successful."
}

###############################################################################
# MAIN DISPATCH TABLE
###############################################################################
case "$cmd" in
  ###########################################################################
  # NEW: self-update
  ###########################################################################
  update|--update)
    update_snapshot
    ;;

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
  # Archive snapshots
  ###########################################################################
  archive|--archive)
    archive_snapshots "$@"
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

    # Final separator preference
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

    # Sorting
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

      # Dynamic column widths
      header_name="Project"   ; header_num="Snapshots"
      header_size="Size(KB)"  ; header_latest="Latest"
      max_name=${#header_name}; max_num=${#header_num}; max_size=${#header_size}
      while IFS='|' read -r n num size _e _l; do
        (( ${#n}   > max_name )) && max_name=${#n}
        (( ${#num} > max_num  )) && max_num=${#num}
        (( ${#size}> max_size )) && max_size=${#size}
      done <<<"$sorted"

      dash() { printf '%*s' "$1" '' | tr ' ' '-'; }
      sep=$([[ "$use_sep" == true ]] && echo ' | ' || echo '  ')

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
  # Persist separator or verbosity preferences
  ###########################################################################
  set-separators:*|--set-separators:*)
    val="${cmd#*:}"
    case "$val" in on|off);; *)
      echo "snapshot: use set-separators:on|off"; exit 2 ;; esac
    need_jq "--set-separators"
    jq --argjson b $([[ $val == on ]] && echo true || echo false) '
      (.settings             //= {}) |
      (.settings.preferences //= {}) |
      .settings.preferences.separators = $b
    ' "$global_cfg" > cfg.tmp && mv cfg.tmp "$global_cfg"
    echo "snapshot: preferences.separators set to $val."
    ;;

  set-verbose:*|--set-verbose:*)
    val="${cmd#*:}"
    case "$val" in mute|minimal|normal|verbose|debug);; *)
      echo "snapshot: use set-verbose:mute|minimal|normal|verbose|debug" >&2
      exit 2 ;;
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
  # List snapshots
  ###########################################################################
  list|-l|--list|list-snapshots|--list-snapshots)
    list_snapshots "$@"
    ;;
  ###########################################################################
  # Restore snapshot                                                        #
  ###########################################################################
  restore|--restore)
      restore_snapshot "$@"
    ;;

  ###########################################################################
  # Misc passthrough commands (unchanged)
  ###########################################################################
  config|-c|--config)                                     show_config              ;;
  ignore|-i|--ignore)                                     add_ignores "$@"         ;;
  remove-ignore|--remove-ignore)                          remove_ignores "$@"      ;;
  remove-all-ignored|--remove-all-ignored)                remove_all_ignored      ;;
  remove-all-ignored-paths|--remove-all-ignored-paths)    remove_all_ignored_paths;;
  remove-all-ignored-files|--remove-all-ignored-files)    remove_all_ignored_files;;
  use-gitignore|--use-gitignore)                          use_gitignore            ;;
  add-type|--add-type)                                    add_types "$@"           ;;
  remove-type|--remove-type)                              remove_types "$@"        ;;
  remove-all-types|--remove-all-types)                    remove_all_types         ;;
  add-default-types|--add-default-types)                  add_default_types        ;;

  ###########################################################################
  # Default: dump → (optional) copy/print → save → summary
  ###########################################################################
  "")
    raw_dump=$(dump_code)

    #######################################################################
    # 1. Clipboard copy (if requested)
    #######################################################################
    if $do_copy; then
      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "$raw_dump" | pbcopy
        bytes=$(printf '%s\n' "$raw_dump" | wc -c)
        echo "snapshot: copied $bytes bytes to clipboard."
      else
        echo "snapshot: install 'pbcopy' first."
      fi
    fi

    #######################################################################
    # 2. Print to stdout (if requested)
    #######################################################################
    $do_print && printf '%s\n' "$raw_dump"

    #######################################################################
    # 3. Save snapshot (unless --no-snapshot)
    #######################################################################
    saved_paths=""
    if ! $no_snapshot; then
      saved_paths=$(printf '%s\n' "$raw_dump" | save_snapshot)
    fi

    #######################################################################
    # 4. Verbosity-aware summary (table for verbose / debug)
    #######################################################################
    case "$verbosity_override" in
      mute)
        :                                   # absolutely nothing
        ;;

      minimal|normal)
        if [[ -n "$saved_paths" ]]; then
          last=$(printf '%s\n' "$saved_paths" | tail -n1)
          echo "[${last##*/}] created"
        fi
        ;;

      verbose|debug)
        # ── collect rows ────────────────────────────────────────────────
        rows=()
        while IFS= read -r snapfile; do
          name=$(basename "$snapfile")
          files=$(grep -c "^=====" "$snapfile")
          lines=$(wc -l < "$snapfile" | tr -d ' ')
          size=$(du -h "$snapfile" | awk '{print $1}')
          rows+=( "$name|$files|$lines|$size|$snapfile" )
        done <<<"$saved_paths"

        # ── compute column widths ───────────────────────────────────────
        header_name="Snapshot"
        header_files="Files"
        header_lines="Lines"
        header_size="Size"
        header_loc="Location"

        max_name=${#header_name}
        max_files=${#header_files}
        max_lines=${#header_lines}
        max_size=${#header_size}

        for row in "${rows[@]}"; do
          IFS='|' read -r n f l s _path <<<"$row"
          (( ${#n} > max_name  )) && max_name=${#n}
          (( ${#f} > max_files )) && max_files=${#f}
          (( ${#l} > max_lines )) && max_lines=${#l}
          (( ${#s} > max_size  )) && max_size=${#s}
        done

        dash() { printf '%*s' "$1" '' | tr ' ' '-'; }

        # ── separator choice (config-driven) ────────────────────────────
        cfg_sep=$(jq -r '.settings.preferences.separators // true' \
                     "$global_cfg" 2>/dev/null || echo true)
        if [[ "$cfg_sep" == true ]]; then sep=' | '; else sep='  '; fi

        # ── header ──────────────────────────────────────────────────────
        printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
               "$header_name" "$header_files" "$header_lines" "$header_size" "$header_loc"
        printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
               "$(dash "$max_name")" "$(dash "$max_files")" "$(dash "$max_lines")" "$(dash "$max_size")" \
               "$(dash ${#header_loc})"

        # ── rows ────────────────────────────────────────────────────────
        for row in "${rows[@]}"; do
          IFS='|' read -r n f l s p <<<"$row"
          printf "%-${max_name}s${sep}%${max_files}s${sep}%${max_lines}s${sep}%${max_size}s${sep}%s\n" \
                 "$n" "$f" "$l" "$s" "$p"
        done

        # (debug no longer prints full snapshot contents)
        ;;
    esac
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
  archive, --archive
  projects, --projects
  set-separators:on|off
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
  restore, --restore
projects options:
  details / --details           add Snapshots / Size / Latest columns
  asc:KEY | desc:KEY            sort by name | size | date   (asc default)
  separators:on|off             override column separators

Global flags (place **before** any command):
  --verbose:mute|minimal|normal|verbose|debug
  --name NAME …
  --tag TAG …
  --to DIR …
  --no-snapshot
  --print
  --copy
EOF
    exit 2
    ;;
esac
