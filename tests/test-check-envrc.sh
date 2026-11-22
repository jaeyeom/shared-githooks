#!/usr/bin/env bash
# Test: check-envrc.sh enforces secret-free .envrc/.envrc.local/.envrc.user
# and keeps .envrc.secrets untracked and gitignored without leaking values.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.githooks/pre-commit/checks/check-envrc.sh"

# Isolate from any git environment leaked in by an invoking hook.
for v in $(git rev-parse --local-env-vars 2>/dev/null || true); do
  unset "$v" 2>/dev/null || true
done

FAILED=0
fail() {
  echo "FAIL: $1" >&2
  FAILED=1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/envrctest.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

init_repo() {
  local dir="$1"
  git init -q "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name "Test"
}

run_hook() {
  local dir="$1"
  (cd "$dir" && bash "$HOOK")
}

# --- Case 1: Clean .envrc, .envrc.local, .envrc.user with dynamic lookups + ignored .envrc.secrets ---
R1="$WORK/r1"
init_repo "$R1"
cat >"$R1/.gitignore" <<'EOF'
.envrc.local
.envrc.user
.envrc.secrets
EOF
cat >"$R1/.envrc" <<'EOF'
use flake
export GITHUB_TOKEN="$(gh auth token)"
export API_KEY="$(op read op://vault/item/key)"
export APP_SECRET="${MY_APP_SECRET}"
export PASSWORD=""
source_env_if_exists .envrc.local
source_env_if_exists .envrc.secrets
EOF
cat >"$R1/.envrc.local" <<'EOF'
# Local non-secret overrides
export LOG_LEVEL=debug
EOF
cat >"$R1/.envrc.secrets" <<'EOF'
export GITHUB_TOKEN="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
EOF
git -C "$R1" add .gitignore .envrc
if ! run_hook "$R1" 2>/dev/null; then
  fail "clean envrc setup: should have passed"
fi

# --- Case 2: Staging .envrc.secrets fails ---
R2="$WORK/r2"
init_repo "$R2"
echo "export FOO=bar" >"$R2/.envrc.secrets"
git -C "$R2" add -f .envrc.secrets
out2=""
if out2=$(run_hook "$R2" 2>&1); then
  fail "staged .envrc.secrets: should have failed"
fi
echo "$out2" | grep -q "\.envrc\.secrets" || fail "staged .envrc.secrets: missing path in output"

# --- Case 3: Unignored .envrc.secrets fails ---
R3="$WORK/r3"
init_repo "$R3"
echo "export FOO=bar" >"$R3/.envrc.secrets"
out3=""
if out3=$(run_hook "$R3" 2>&1); then
  fail "unignored .envrc.secrets: should have failed"
fi
echo "$out3" | grep -q "not gitignored" || fail "unignored .envrc.secrets: missing gitignore warning"

# --- Case 4: Untracked .envrc.local with token pattern fails without printing secret ---
R4="$WORK/r4"
init_repo "$R4"
echo ".envrc.local" >"$R4/.gitignore"
FAKE_TOKEN="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
echo "export MY_VAR=\"$FAKE_TOKEN\"" >"$R4/.envrc.local"
out4=""
if out4=$(run_hook "$R4" 2>&1); then
  fail "token in .envrc.local: should have failed"
fi
echo "$out4" | grep -q "\.envrc\.local:1" || fail "token in .envrc.local: missing file:line in output"
if echo "$out4" | grep -q "$FAKE_TOKEN"; then
  fail "token in .envrc.local: leaked token value in output"
fi

# --- Case 5: Literal sensitive variable assignment in .envrc.user fails without printing value ---
R5="$WORK/r5"
init_repo "$R5"
echo ".envrc.user" >"$R5/.gitignore"
echo 'export STRIPE_API_KEY="my-literal-secret-value"' >"$R5/.envrc.user"
out5=""
if out5=$(run_hook "$R5" 2>&1); then
  fail "literal sensitive var in .envrc.user: should have failed"
fi
echo "$out5" | grep -q "STRIPE_API_KEY" || fail "literal sensitive var: missing variable name in output"
if echo "$out5" | grep -q "my-literal-secret-value"; then
  fail "literal sensitive var: leaked secret value in output"
fi

# --- Case 6: Credentialed URL in .envrc fails without printing password ---
R6="$WORK/r6"
init_repo "$R6"
echo 'export PROXY_URL="https://alice:supersecret99@proxy.example.com:8080"' >"$R6/.envrc"
out6=""
if out6=$(run_hook "$R6" 2>&1); then
  fail "credentialed URL in .envrc: should have failed"
fi
echo "$out6" | grep -q "\.envrc:1" || fail "credentialed URL in .envrc: missing file:line"
if echo "$out6" | grep -q "supersecret99"; then
  fail "credentialed URL in .envrc: leaked password in output"
fi

# --- Case 7: Opt-out via hooks.checkenvrc false ---
R7="$WORK/r7"
init_repo "$R7"
echo 'export API_KEY="plain-secret"' >"$R7/.envrc"
git -C "$R7" config hooks.checkenvrc false
if ! run_hook "$R7" 2>/dev/null; then
  fail "opt-out: hooks.checkenvrc false should skip the check"
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "OK: check-envrc.sh passed all test cases."
