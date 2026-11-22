#!/usr/bin/env bash
# Test: check-git-config.sh detects sensitive information in local/worktree
# Git config without leaking values or failing on SSH URLs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/.githooks/pre-commit/checks/check-git-config.sh"

# Isolate from any git environment leaked in by an invoking hook.
for v in $(git rev-parse --local-env-vars 2>/dev/null || true); do
  unset "$v" 2>/dev/null || true
done

FAILED=0
fail() {
  echo "FAIL: $1" >&2
  FAILED=1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gitconfigtest.XXXXXX")"
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

# --- Case 1: Clean config passes ---
R1="$WORK/r1"
init_repo "$R1"
git -C "$R1" remote add origin "https://github.com/example/repo.git"
if ! run_hook "$R1" 2>/dev/null; then
  fail "clean config: should have passed"
fi

# --- Case 2: SSH and SCP-style URLs do not false-positive ---
R2="$WORK/r2"
init_repo "$R2"
git -C "$R2" remote add origin "git@github.com:example/repo.git"
git -C "$R2" remote add backup "ssh://git@example.com:2222/repo.git"
git -C "$R2" config url."ssh://git@github.com/".insteadOf "https://github.com/"
if ! run_hook "$R2" 2>/dev/null; then
  fail "ssh URLs: should not trigger false positive"
fi

# --- Case 3: Credentialed remote.origin.url and pushurl fail without printing value ---
R3="$WORK/r3"
init_repo "$R3"
SECRET_URL="https://alice:supersecretpass@github.com/example/repo.git"
git -C "$R3" remote add origin "$SECRET_URL"
git -C "$R3" remote set-url --push origin "https://bob:anothersecret@github.com/example/repo.git"
out3=""
if out3=$(run_hook "$R3" 2>&1); then
  fail "credentialed remote url: should have failed"
fi
echo "$out3" | grep -q "remote.origin.url" || fail "credentialed remote url: missing key in output"
echo "$out3" | grep -q "remote.origin.pushurl" || fail "credentialed pushurl: missing key in output"
if echo "$out3" | grep -qE "supersecretpass|anothersecret"; then
  fail "credentialed remote url: leaked secret value in output"
fi

# --- Case 4: url.<cred>.insteadOf fails and redacts credentials in key name ---
R4="$WORK/r4"
init_repo "$R4"
git -C "$R4" config "url.https://user:my_key_secret@github.com/.insteadOf" "https://github.com/"
out4=""
if out4=$(run_hook "$R4" 2>&1); then
  fail "url.<cred>.insteadOf: should have failed"
fi
echo "$out4" | grep -q "url.https://\*\*\*@github.com/.insteadof" || fail "url.<cred>.insteadOf: key not redacted as expected"
if echo "$out4" | grep -q "my_key_secret"; then
  fail "url.<cred>.insteadOf: leaked secret from key name"
fi

# --- Case 5: http.extraheader and http.<url>.extraheader (case-insensitive) ---
R5="$WORK/r5"
init_repo "$R5"
git -C "$R5" config http.extraheader "authorization: Bearer secret-bearer-123"
git -C "$R5" config "http.https://example.com/.extraheader" "Proxy-Authorization: Basic dXNlcjpwYXNz"
out5=""
if out5=$(run_hook "$R5" 2>&1); then
  fail "http extraheader: should have failed"
fi
echo "$out5" | grep -q "http.extraheader" || fail "http.extraheader: missing key in output"
echo "$out5" | grep -q "http.https://example.com/.extraheader" || fail "http.<url>.extraheader: missing key in output"
if echo "$out5" | grep -qE "secret-bearer-123|dXNlcjpwYXNz"; then
  fail "http extraheader: leaked header value in output"
fi

# --- Case 6: Token patterns in arbitrary config values fail without printing value ---
R6="$WORK/r6"
init_repo "$R6"
FAKE_TOKEN="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
git -C "$R6" config custom.apitoken "$FAKE_TOKEN"
out6=""
if out6=$(run_hook "$R6" 2>&1); then
  fail "token pattern: should have failed"
fi
echo "$out6" | grep -q "custom.apitoken" || fail "token pattern: missing key in output"
if echo "$out6" | grep -q "$FAKE_TOKEN"; then
  fail "token pattern: leaked token value in output"
fi

# --- Case 7: Opt-out via hooks.checkgitconfig false ---
R7="$WORK/r7"
init_repo "$R7"
git -C "$R7" remote add origin "https://user:secret@github.com/example/repo.git"
git -C "$R7" config hooks.checkgitconfig false
if ! run_hook "$R7" 2>/dev/null; then
  fail "opt-out: hooks.checkgitconfig false should skip the check"
fi

# --- Case 8: Worktree config scanned when extensions.worktreeConfig is true ---
R8="$WORK/r8"
init_repo "$R8"
git -C "$R8" config extensions.worktreeConfig true
git -C "$R8" config --worktree http.proxy "http://proxyuser:proxypass@proxy.example.com:8080"
out8=""
if out8=$(run_hook "$R8" 2>&1); then
  fail "worktree config: should have failed"
fi
echo "$out8" | grep -q "http.proxy" || fail "worktree config: missing key in output"
if echo "$out8" | grep -q "proxypass"; then
  fail "worktree config: leaked proxy password in output"
fi

if [ "$FAILED" -ne 0 ]; then
  echo >&2 "check-git-config test failed."
  exit 1
fi

echo "OK: check-git-config hook detects sensitive Git config safely."
