#!/usr/bin/env bash
#
# snapshot/core/save.sh – save_snapshot helper
#
set -euo pipefail

###############################################################################
# 2. Save a snapshot dump to disk                                             #
###############################################################################
save_snapshot() {
  [ "$no_snapshot" = true ] && { cat >/dev/null; return 0; }

  tmp=$(mktemp)
  cat >"$tmp"

  # ── build filename suffix with *bracketed* tag list ──────────────────────
  if ((${#tags[@]})); then
    tag_str=$(IFS=,; echo "[${tags[*]}]")
    suffix="__${tag_str}"
  else
    suffix=""
  fi

  epoch=$(date +%s)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
  branch=${branch//\//_}
  commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

  base_names=()
  if ((${#custom_names[@]})); then
    for n in "${custom_names[@]}"; do
      base_names+=( "${n}${suffix}.snapshot" )
    done
  else
    base_names+=( "${epoch}_${branch}_${commit}${suffix}.snapshot" )
  fi

  # ── destination directory/directories determination ─────────────────────
  if ((${#dest_dirs[@]})); then
    dests=("${dest_dirs[@]}")
  else
    local_cfg="$git_root/config.json"
    proj=""
    if [ -f "$local_cfg" ]; then proj=$(jq -r '.project // empty' "$local_cfg"); fi
    [ -z "$proj" ] && proj=$(jq -r '.project // empty' "$global_cfg")
    [ -z "$proj" ] && proj=$(basename "$git_root")
    dests=( "$cfg_default_dir/$proj" )
  fi

  # ── write snapshot(s) ────────────────────────────────────────────────────
  results=()
  for d in "${dests[@]}"; do
    mkdir -p "$d"
    for b in "${base_names[@]}"; do
      out="$d/$b"
      cp "$tmp" "$out"
      results+=( "$out" )
    done
  done
  rm -f "$tmp"
  printf '%s\n' "${results[@]}"
}
