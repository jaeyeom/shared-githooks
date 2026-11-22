#!/usr/bin/env bash
# Pre-commit: check local (and worktree) Git config for sensitive information.
# Disable with: git config hooks.checkgitconfig false
#
# Because .git/config is untracked, secret scanners that inspect staged files
# or commit history will not catch credentials stored in local Git config.
# This hook scans local Git config entries without printing config values and
# redacts any URL userinfo embedded in config key subsections.

set -euo pipefail

enabled=$(git config --type=bool hooks.checkgitconfig 2>/dev/null || echo "true")
if [ "$enabled" != "true" ]; then
  exit 0
fi

FAILED=0

redact_key() {
  local k="$1"
  local out=""
  local re='([Hh][Tt][Tt][Pp][Ss]?://)[^/@]+@'
  while [[ "$k" =~ $re ]]; do
    local match="${BASH_REMATCH[0]}"
    local scheme="${BASH_REMATCH[1]}"
    out+="${k%%"$match"*}${scheme}***@"
    k="${k#*"$match"}"
  done
  printf '%s%s' "$out" "$k"
}

report_finding() {
  local scope="$1"
  local raw_key="$2"
  local reason="$3"
  local safe_key
  safe_key="$(redact_key "$raw_key")"
  echo >&2 "  [$scope] $safe_key: $reason"
  FAILED=1
}

cred_url_re='[Hh][Tt][Tt][Pp][Ss]?://[^/@]+@'
auth_header_re='(^|[[:space:]])([Pp][Rr][Oo][Xx][Yy]-)?[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn][[:space:]]*:'
secret_re='(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|(AKIA|ASIA)[0-9A-Z]{16}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----)'

scan_scope() {
  local scope="$1"
  local flag="$2"
  local entry key val

  while IFS= read -r -d '' entry; do
    if [[ "$entry" == *$'\n'* ]]; then
      key="${entry%%$'\n'*}"
      val="${entry#*$'\n'}"
    else
      key="$entry"
      val=""
    fi

    # 1. Credentialed URLs in remote URLs, proxies, and url.<base>.(push)?insteadOf
    case "$key" in
      remote.*.url | remote.*.pushurl | http.proxy | remote.*.proxy)
        if [[ "$val" =~ $cred_url_re ]]; then
          report_finding "$scope" "$key" "embedded credentials in URL"
        fi
        ;;
      url.*.insteadof | url.*.pushinsteadof)
        if [[ "$key" =~ $cred_url_re ]] || [[ "$val" =~ $cred_url_re ]]; then
          report_finding "$scope" "$key" "embedded credentials in URL rewrite rule"
        fi
        ;;
    esac

    # 2. Authorization headers in http.extraheader or http.<url>.extraheader
    if [ "$key" = "http.extraheader" ] || [[ "$key" == http.*.extraheader ]]; then
      if [[ "$val" =~ $auth_header_re ]]; then
        report_finding "$scope" "$key" "authorization header in HTTP extraheader"
      fi
    fi

    # 3. Common secret/token patterns in any config value
    if [ -n "$val" ] && [[ "$val" =~ $secret_re ]]; then
      report_finding "$scope" "$key" "potential secret or token pattern in config value"
    fi
  done < <(git config "$flag" --list -z 2>/dev/null || true)
}

scan_scope "local" "--local"

worktree_config=$(git config --type=bool extensions.worktreeConfig 2>/dev/null || echo "false")
if [ "$worktree_config" = "true" ]; then
  scan_scope "worktree" "--worktree"
fi

if [ "$FAILED" -ne 0 ]; then
  cat >&2 <<'EOF'

Sensitive information detected in Git config. Commit aborted.
(Config values are omitted above; any URL credentials in key names are redacted.)

Remediation:
  - For remote URLs with embedded tokens/passwords:
      git remote set-url <remote> https://<host>/<path>
    and configure a credential helper instead of embedding credentials in URLs.
  - For extraheader, proxy, url.*.insteadOf, or token entries:
      git config --local --unset <key>
    (or --worktree --unset <key> if set in worktree config).
  - If a real token or password was stored, rotate/revoke it.

To disable this check, run:

  git config hooks.checkgitconfig false
EOF
  exit 1
fi
