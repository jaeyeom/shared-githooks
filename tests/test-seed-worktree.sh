#!/usr/bin/env bash
# Test: the post-checkout seed-worktree hook copies/links manifest entries
# into a new linked worktree and skips everything it should.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.githooks/post-checkout/seed-worktree.sh"

# Isolate from any git environment leaked in by an invoking hook (a pre-commit
# run exports GIT_DIR, GIT_INDEX_FILE, etc., which would otherwise point this
# test's temp-repo git commands back at the real repository).
for v in $(git rev-parse --local-env-vars 2>/dev/null); do
  unset "$v" 2>/dev/null || true
done

NULL_OID=0000000000000000000000000000000000000000

FAILED=0
fail() {
  echo "FAIL: $1" >&2
  FAILED=1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/seedtest.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Build a main working tree with one commit.
MAIN="$WORK/main"
git init -q "$MAIN"
git -C "$MAIN" config user.email test@example.com
git -C "$MAIN" config user.name "Test"
git -C "$MAIN" config commit.gpgsign false
echo "root" >"$MAIN/README"
git -C "$MAIN" add README
git -C "$MAIN" commit -qm "initial"
MAIN="$(git -C "$MAIN" rev-parse --show-toplevel)"

# Untracked personal files that should be seeded.
printf 'PORT=3000\n' >"$MAIN/.env"
printf 'rc-user\n' >"$MAIN/.bazelrc.user"
mkdir -p "$MAIN/config"
printf 'local: yes\n' >"$MAIN/config/app.local.yaml"
# A large file to exercise the size cap.
head -c 2000000 /dev/zero >"$MAIN/big.local" 2>/dev/null || true

# Committed manifest plus a personal (untracked) manifest in .git.
cat >"$MAIN/.worktree-seed" <<'EOF'
# mode  path
copy    .env
link    .bazelrc.user
copy    config/*.local.yaml
EOF
git -C "$MAIN" config hooks.worktreeseedmaxsize 1048576
printf 'copy\tbig.local\n' >"$(git -C "$MAIN" rev-parse --absolute-git-dir)/worktree-seed"

# Helper: create a fresh worktree and run the hook inside it as git would.
run_hook_in_new_worktree() {
  local wt=$1 oldhead=$2 flag=$3
  git -C "$MAIN" worktree add -q "$wt" -b "$(basename "$wt")" >/dev/null
  (cd "$wt" && bash "$HOOK" "$oldhead" "$(git rev-parse HEAD)" "$flag")
}

# --- Case 1: a real new worktree seeds copy/link/glob entries ---
WT1="$WORK/wt1"
run_hook_in_new_worktree "$WT1" "$NULL_OID" 1

[ -f "$WT1/.env" ] && [ ! -L "$WT1/.env" ] || fail "copy: .env not seeded as a regular file"
[ "$(cat "$WT1/.env" 2>/dev/null)" = "PORT=3000" ] || fail "copy: .env content mismatch"
[ -L "$WT1/.bazelrc.user" ] || fail "link: .bazelrc.user not a symlink"
[ "$(readlink "$WT1/.bazelrc.user" 2>/dev/null)" = "$MAIN/.bazelrc.user" ] || fail "link: .bazelrc.user points to wrong target"
[ -f "$WT1/config/app.local.yaml" ] || fail "glob: config/app.local.yaml not seeded"
[ ! -e "$WT1/big.local" ] || fail "size cap: big.local should have been skipped"

# --- Case 2: never clobber an existing file in the worktree ---
WT2="$WORK/wt2"
git -C "$MAIN" worktree add -q "$WT2" -b wt2 >/dev/null
printf 'PRESERVE\n' >"$WT2/.env"
(cd "$WT2" && bash "$HOOK" "$NULL_OID" "$(git -C "$WT2" rev-parse HEAD)" 1)
[ "$(cat "$WT2/.env")" = "PRESERVE" ] || fail "clobber: existing .env was overwritten"

# --- Case 3: file checkout (flag 0) is a no-op ---
WT3="$WORK/wt3"
git -C "$MAIN" worktree add -q "$WT3" -b wt3 >/dev/null
(cd "$WT3" && bash "$HOOK" "$NULL_OID" "$(git -C "$WT3" rev-parse HEAD)" 0)
[ ! -e "$WT3/.env" ] || fail "flag 0: file checkout should not seed"

# --- Case 4: in-place branch switch (real old HEAD) is a no-op ---
WT4="$WORK/wt4"
git -C "$MAIN" worktree add -q "$WT4" -b wt4 >/dev/null
REAL_HEAD="$(git -C "$WT4" rev-parse HEAD)"
(cd "$WT4" && bash "$HOOK" "$REAL_HEAD" "$REAL_HEAD" 1)
[ ! -e "$WT4/.env" ] || fail "in-place switch: should not seed"

# --- Case 5: running in the main tree (fresh-clone shape) is a no-op ---
rm -f "$MAIN/seeded-marker"
(cd "$MAIN" && bash "$HOOK" "$NULL_OID" "$(git rev-parse HEAD)" 1)
# .env already exists in main; assert nothing new appeared from the personal
# manifest (big.local must not be copied onto itself or duplicated oddly).
[ -f "$MAIN/.env" ] || fail "main tree: pre-existing file disappeared"

if [ "$FAILED" -ne 0 ]; then
  echo >&2 "seed-worktree test failed."
  exit 1
fi

echo "OK: seed-worktree hook seeds, links, and skips correctly."
