#!/usr/bin/env bash
# Pre-commit: run affected Bazel tests.
# Skips if no BUILD/BUILD.bazel file or bazel is not installed.
# Skips if the Makefile check target already runs bazel test.
# Falls back to `bazel test //...:all` if bazel-affected-tests is not installed.

set -euo pipefail

if [ ! -f BUILD ] && [ ! -f BUILD.bazel ]; then
  exit 0
fi

if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -qE 'bazel\b.*\btest\b' Makefile 2>/dev/null; then
  echo "Skipping standalone Bazel tests: Makefile has check target and mentions bazel test"
  exit 0
fi

if ! command -v bazel &>/dev/null; then
  echo "Warning: bazel not found, skipping Bazel tests" >&2
  exit 0
fi

if command -v bazel-affected-tests &>/dev/null; then
  echo "Finding affected tests..."
  AFFECTED_TESTS=$(bazel-affected-tests 2>/dev/null) || {
    echo "Warning: bazel-affected-tests failed, falling back to full test" >&2
    if ! bazel test --test_summary=terse //...:all; then
      echo >&2 "Bazel tests failed. Commit aborted."
      exit 1
    fi
    exit 0
  }

  if [ -z "$AFFECTED_TESTS" ]; then
    echo "No affected tests found — skipping."
    exit 0
  fi

  echo "Running affected tests:"
  while IFS= read -r t; do echo "  $t"; done <<<"$AFFECTED_TESTS"

  # Separate format tests from other tests
  FORMAT_TESTS=$(echo "$AFFECTED_TESTS" | grep "//tools/format:" || true)
  OTHER_TESTS=$(echo "$AFFECTED_TESTS" | grep -v "//tools/format:" || true)

  if [ -n "$FORMAT_TESTS" ]; then
    echo "Running format tests..."
    if ! echo "$FORMAT_TESTS" | xargs bazel test --test_summary=terse; then
      echo "Format tests failed. Running auto-formatter..."
      bazel run //:format 2>/dev/null || true
      echo >&2 "Commit failed: code was not formatted properly and has been reformatted. Please review and commit again."
      exit 1
    fi
  fi

  if [ -n "$OTHER_TESTS" ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
      echo "Skipping affected tests on Darwin."
    elif ! echo "$OTHER_TESTS" | xargs bazel test --test_summary=terse; then
      echo >&2 "Bazel tests failed. Commit aborted."
      exit 1
    fi
  fi

  echo "All affected tests passed."
else
  echo "Warning: bazel-affected-tests not found, running all tests..." >&2
  if ! bazel test --test_summary=terse //...:all; then
    echo >&2 "Bazel tests failed. Commit aborted."
    exit 1
  fi
  echo "All tests passed."
fi
