#!/usr/bin/env bash
# Pre-commit: when a doc file changes, all its language variants must too.
# Opt-in: git config hooks.i18nsync true
#
# Languages are auto-discovered from tracked README.<lang>.md files.
# Tracked file groups (example with ko, ja):
#   README.md  <-> README.ko.md  <-> README.ja.md
#   docs/*.md  <-> docs/ko/*.md  <-> docs/ja/*.md

set -euo pipefail

i18nsync=$(git config --type=bool hooks.i18nsync 2>/dev/null || echo "false")
if [ "$i18nsync" != "true" ]; then
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACMR)

if [ -z "$STAGED" ]; then
  exit 0
fi

# Auto-discover languages from tracked README.<lang>.md files.
LANGS=()
while IFS= read -r f; do
  lang="${f#README.}"
  lang="${lang%.md}"
  LANGS+=("$lang")
done < <(git ls-files 'README.*.md')

if [ "${#LANGS[@]}" -eq 0 ]; then
  exit 0
fi

FAILED=0

missing() {
  echo >&2 "  $1 is staged but $2 is not"
  FAILED=1
}

# --- README files ---

readme_variants=("README.md")
for lang in "${LANGS[@]}"; do
  readme_variants+=("README.${lang}.md")
done

# Check if any README variant is staged.
staged_readme=0
for v in "${readme_variants[@]}"; do
  if echo "$STAGED" | grep -qx "$v"; then
    staged_readme=1
    break
  fi
done

if [ "$staged_readme" -eq 1 ]; then
  for v in "${readme_variants[@]}"; do
    if ! echo "$STAGED" | grep -qx "$v"; then
      # Find which variant triggered this.
      for s in "${readme_variants[@]}"; do
        if echo "$STAGED" | grep -qx "$s"; then
          missing "$s" "$v"
          break
        fi
      done
    fi
  done
fi

# --- docs/ files ---

# Collect staged docs/ files and map to their base names.
staged_docs=$(echo "$STAGED" | grep '^docs/' || true)

if [ -n "$staged_docs" ]; then
  # Normalize each staged doc path to its base name (language-independent).
  # docs/getting-started.md       -> getting-started.md
  # docs/ko/getting-started.md    -> getting-started.md
  seen_bases=()

  while IFS= read -r path; do
    [ -z "$path" ] && continue
    # Strip "docs/" prefix.
    rest="${path#docs/}"
    # Strip language prefix if present.
    base="$rest"
    for lang in "${LANGS[@]}"; do
      if [[ "$rest" == "${lang}/"* ]]; then
        base="${rest#"${lang}/"}"
        break
      fi
    done
    # Deduplicate.
    already=0
    for b in "${seen_bases[@]+"${seen_bases[@]}"}"; do
      if [ "$b" = "$base" ]; then
        already=1
        break
      fi
    done
    if [ "$already" -eq 0 ]; then
      seen_bases+=("$base")
    fi
  done <<<"$staged_docs"

  # For each base name, build the set of tracked variants and enforce
  # sync only when at least two variants exist (i.e., the file actually
  # has translations).  This avoids false positives for non-translated
  # subdirectories like docs/api/ or docs/architecture/.
  for base in "${seen_bases[@]+"${seen_bases[@]}"}"; do
    all_variants=("docs/$base")
    for lang in "${LANGS[@]}"; do
      all_variants+=("docs/$lang/$base")
    done

    # Keep only variants that are tracked in git.
    tracked_variants=()
    for v in "${all_variants[@]}"; do
      if git ls-files --error-unmatch "$v" >/dev/null 2>&1; then
        tracked_variants+=("$v")
      fi
    done

    # Skip files that have no translation counterparts.
    if [ "${#tracked_variants[@]}" -lt 2 ]; then
      continue
    fi

    # Find a staged variant to use in the error message.
    staged_one=""
    for v in "${tracked_variants[@]}"; do
      if echo "$STAGED" | grep -qx "$v"; then
        staged_one="$v"
        break
      fi
    done

    for v in "${tracked_variants[@]}"; do
      if ! echo "$STAGED" | grep -qx "$v"; then
        missing "$staged_one" "$v"
      fi
    done
  done
fi

if [ "$FAILED" -ne 0 ]; then
  cat >&2 <<'EOF'

i18n sync check failed. Commit aborted.

When changing a documentation file, update all language variants together.

To disable this check, run:

  git config hooks.i18nsync false
EOF
  exit 1
fi
