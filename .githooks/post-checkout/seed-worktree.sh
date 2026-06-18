#!/usr/bin/env bash
# Post-checkout: seed untracked personal files into a newly created worktree.
#
# When `git worktree add` creates a linked worktree, untracked/gitignored
# files (.env, .bazelrc.user, ...) don't come along. This hook copies or
# symlinks them from the main working tree, driven by a manifest so it only
# touches files you opt in to — never build outputs, caches, or secrets you
# didn't list.
#
# Manifest format (one entry per line, `#` comments and blanks ignored):
#   copy  .env              # independent seed per worktree
#   link  .bazelrc.user     # symlink to a single shared source
#   copy  config/*.local.yaml
#
# Manifests are read from the main tree's filesystem (tracked or not):
#   <git-common-dir>/worktree-seed   personal, untracked, never in git status
#   <main-tree>/.worktree-seed       committed team-wide baseline
# Both are layered; the personal manifest wins on conflicting paths.

set -euo pipefail

old_head="${1:-}"
flag="${3:-}"

# Only branch checkouts (flag 1), not file checkouts (flag 0).
if [ "$flag" != "1" ]; then
  exit 0
fi

# A fresh checkout into a tree passes the null OID as the old HEAD; an
# in-place branch switch passes a real SHA. Skip in-place switches.
if ! [[ "$old_head" =~ ^0+$ ]]; then
  exit 0
fi

# Distinguish a new linked worktree from a fresh clone of the main tree:
# only linked worktrees have a git-dir different from the common dir.
abs_git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(git rev-parse --git-common-dir)
case "$common_dir" in
  /*) ;;
  *) common_dir="$(pwd)/$common_dir" ;;
esac
common_dir=$(cd "$common_dir" && pwd)
if [ "$abs_git_dir" = "$common_dir" ]; then
  exit 0
fi

# A submodule also has git-dir != common-dir; don't seed inside one.
if [ -n "$(git rev-parse --show-superproject-working-tree 2>/dev/null || true)" ]; then
  exit 0
fi

# The main working tree is the first entry of the porcelain worktree list.
MAIN_TREE=$(git worktree list --porcelain \
  | awk '/^worktree /{sub(/^worktree /, ""); print; exit}')
NEW_TREE=$(git rev-parse --show-toplevel)

if [ -z "$MAIN_TREE" ] || [ "$MAIN_TREE" = "$NEW_TREE" ]; then
  exit 0
fi

DEFAULT_MAX_SIZE=1048576 # 1 MB
MAX_SIZE=$(git config --int hooks.worktreeseedmaxsize 2>/dev/null || echo "$DEFAULT_MAX_SIZE")

human_size() {
  local bytes=$1
  if [ "$bytes" -ge 1048576 ]; then
    echo "$((bytes / 1048576)) MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$((bytes / 1024)) KB"
  else
    echo "${bytes} bytes"
  fi
}

seed_one() {
  local mode=$1 rel=$2

  # Only allow safe relative paths. An absolute path or a ".." segment could
  # read from or write to locations outside the trees, so refuse it before
  # touching the filesystem.
  case "$rel" in
    "" | /*)
      echo "worktree-seed: refusing non-relative path '$rel'" >&2
      return 0
      ;;
  esac
  case "/$rel/" in
    */../*)
      echo "worktree-seed: refusing path with '..' segment: '$rel'" >&2
      return 0
      ;;
  esac

  local src="$MAIN_TREE/$rel"
  local dst="$NEW_TREE/$rel"

  # Must exist in the main tree, and be a plain regular file.
  if [ ! -e "$src" ] || [ -L "$src" ] || [ -d "$src" ]; then
    return 0
  fi

  # Never clobber: skip anything already present in the new worktree
  # (including tracked files that were just checked out).
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    return 0
  fi

  local size
  size=$(wc -c <"$src" | tr -d ' ')
  if [ "$size" -gt "$MAX_SIZE" ]; then
    echo "worktree-seed: skipping $rel ($(human_size "$size") exceeds $(human_size "$MAX_SIZE") cap)" >&2
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  case "$mode" in
    copy)
      cp "$src" "$dst"
      echo "worktree-seed: copied $rel"
      ;;
    link)
      ln -s "$src" "$dst"
      echo "worktree-seed: linked $rel -> $src"
      ;;
    *)
      echo "worktree-seed: unknown mode '$mode' for '$rel' (use copy or link)" >&2
      ;;
  esac
}

process_manifest() {
  local manifest=$1
  if [ ! -f "$manifest" ]; then
    return 0
  fi

  local line mode rest
  while IFS= read -r line || [ -n "$line" ]; do
    # Trim leading whitespace, then drop blanks and comments.
    line="${line#"${line%%[![:space:]]*}"}"
    if [ -z "$line" ] || [ "${line:0:1}" = "#" ]; then
      continue
    fi

    mode="${line%%[[:space:]]*}"
    rest="${line#"$mode"}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    # Strip an inline comment (whitespace followed by '#' to end of line),
    # then trim any whitespace it left behind.
    rest="${rest%%[[:space:]]#*}"
    rest="${rest%"${rest##*[![:space:]]}"}"
    if [ -z "$rest" ] || [ "${rest:0:1}" = "#" ]; then
      echo "worktree-seed: ignoring manifest line without a path: $line" >&2
      continue
    fi

    # Expand the pattern relative to the main tree.
    local matched
    while IFS= read -r -d '' matched; do
      seed_one "$mode" "$matched"
    done < <(
      cd "$MAIN_TREE" || exit 0
      shopt -s nullglob dotglob
      # shellcheck disable=SC2206 # word splitting and globbing are intended
      local hits=($rest)
      local h
      for h in "${hits[@]}"; do
        printf '%s\0' "$h"
      done
    )
  done <"$manifest"
}

# Personal manifest first so it wins on paths listed in both.
process_manifest "$common_dir/worktree-seed"
process_manifest "$MAIN_TREE/.worktree-seed"
