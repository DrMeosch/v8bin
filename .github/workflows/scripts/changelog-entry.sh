#!/bin/sh
# Usage: changelog-entry.sh DATE PR_URL COMMIT_URL < pr-body
# Prints the changelog issue comment for a merged PR, or nothing when the PR's
# Changelog section is empty or "none".

date="$1" pr_url="$2" commit_url="$3"

section="$(sh "$(dirname "$0")/changelog-section.sh" | sed 's/@/@\xe2\x80\x8b/g')"
trimmed="$(printf '%s' "$section" | tr -d '[:space:][:punct:]' | tr '[:upper:]' '[:lower:]')"

case "$trimmed" in
  '' | none) exit 0 ;;
esac

printf '**%s** - %s - [merge commit](%s)\n\n%s\n' "$date" "$pr_url" "$commit_url" "$section"
