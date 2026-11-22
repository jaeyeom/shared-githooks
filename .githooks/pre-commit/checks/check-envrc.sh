#!/usr/bin/env bash
# Pre-commit: enforce secret-free .envrc / .envrc.local / .envrc.user and
# prevent committing or leaving .envrc.secrets unignored.
# Disable with: git config hooks.checkenvrc false
#
# Model:
#   - .envrc, .envrc.local, .envrc.user: readable by agents; must not contain
#     literal secrets (command substitutions like $(op read ...) are allowed).
#   - .envrc.secrets: holds actual secrets; must be gitignored and never staged.

set -euo pipefail

enabled=$(git config --type=bool hooks.checkenvrc 2>/dev/null || echo "true")
if [ "$enabled" != "true" ]; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FAILED=0

report_finding() {
  local location="$1"
  local reason="$2"
  echo >&2 "  $location: $reason"
  FAILED=1
}

# 1. Never allow .envrc.secrets to be staged.
while IFS= read -r -d '' staged_path; do
  case "$staged_path" in
    .envrc.secrets | */.envrc.secrets)
      report_finding "[staged] $staged_path" ".envrc.secrets must never be committed"
      ;;
  esac
done < <(git diff --cached --name-only -z --diff-filter=ACM 2>/dev/null || true)

# 2. Ensure any existing .envrc.secrets is gitignored (and not tracked).
while IFS= read -r -d '' unignored_secrets; do
  report_finding "$unignored_secrets" ".envrc.secrets is not gitignored (add it to .gitignore)"
done < <(git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard -- '.envrc.secrets' '**/.envrc.secrets' 2>/dev/null || true)

# 3. Collect .envrc, .envrc.local, .envrc.user (tracked, unignored, or gitignored at root).
declare -a envrc_files=()
add_envrc_file() {
  local abs="$1"
  [ -f "$abs" ] || return 0
  local existing
  for existing in "${envrc_files[@]+"${envrc_files[@]}"}"; do
    if [ "$existing" = "$abs" ]; then
      return 0
    fi
  done
  envrc_files+=("$abs")
}

for name in .envrc .envrc.local .envrc.user; do
  add_envrc_file "$REPO_ROOT/$name"
done

while IFS= read -r -d '' rel_path; do
  add_envrc_file "$REPO_ROOT/$rel_path"
done < <(git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard -- \
  '.envrc' '.envrc.local' '.envrc.user' \
  '**/.envrc' '**/.envrc.local' '**/.envrc.user' 2>/dev/null || true)

cred_url_re='[Hh][Tt][Tt][Pp][Ss]?://[^/@[:space:]"'\'']+@'
secret_re='(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|(AKIA|ASIA)[0-9A-Z]{16}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----)'
assign_re='^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$'
sensitive_var_re='(^|_)(SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|APIKEY|AUTH_KEY|PRIVATE_KEY|ACCESS_KEY|CLIENT_SECRET|CREDENTIAL|CREDENTIALS)$'

is_safe_rhs() {
  local val="$1"
  # Trim leading/trailing whitespace.
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"

  # Strip matching outer single or double quotes.
  case "$val" in
    \"*\")
      val="${val#\"}"
      val="${val%\"}"
      ;;
    \'*\')
      val="${val#\'}"
      val="${val%\'}"
      ;;
  esac

  # Empty or pure inline comment.
  if [ -z "$val" ] || [[ "$val" == \#* ]]; then
    return 0
  fi

  # Variable expansion, command substitution, or secret-manager URI reference.
  case "$val" in
    \$* | \`* | op://* | vault:* | aws-ssm://*)
      return 0
      ;;
  esac

  return 1
}

scan_envrc_file() {
  local abs="$1"
  local rel="${abs#"$REPO_ROOT"/}"
  local lineno=0
  local line var val

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # Skip pure comment lines.
    case "$line" in
      [[:space:]]*\#* | \#*)
        continue
        ;;
    esac

    if [[ "$line" =~ $cred_url_re ]]; then
      report_finding "$rel:$lineno" "embedded credentials in URL (move to .envrc.secrets)"
      continue
    fi

    if [[ "$line" =~ $secret_re ]]; then
      report_finding "$rel:$lineno" "potential secret or token pattern (move to .envrc.secrets)"
      continue
    fi

    if [[ "$line" =~ $assign_re ]]; then
      var="${BASH_REMATCH[2]}"
      val="${BASH_REMATCH[3]}"
      # Strip trailing unquoted comment (e.g., FOO=bar # note).
      if [[ "$val" =~ ^([^\"\'#]*)[[:space:]]+# ]]; then
        val="${BASH_REMATCH[1]}"
      fi
      shopt -s nocasematch
      local is_sensitive=0
      if [[ "$var" =~ $sensitive_var_re ]]; then
        is_sensitive=1
      fi
      shopt -u nocasematch

      if [ "$is_sensitive" -eq 1 ] && ! is_safe_rhs "$val"; then
        report_finding "$rel:$lineno" "literal value assigned to sensitive variable '$var' (move to .envrc.secrets)"
      fi
    fi
  done <"$abs"
}

for f in "${envrc_files[@]+"${envrc_files[@]}"}"; do
  scan_envrc_file "$f"
done

if [ "$FAILED" -ne 0 ]; then
  cat >&2 <<'EOF'

direnv policy violation detected. Commit aborted.
(Secret values are omitted above.)

Remediation:
  - Move literal secrets, tokens, and credentialed URLs to .envrc.secrets,
    or use a dynamic lookup (e.g. $(op read ...), $(gh auth token)) in .envrc.
  - Ensure .envrc.secrets is listed in .gitignore and never staged.

To disable this check, run:

  git config hooks.checkenvrc false
EOF
  exit 1
fi
