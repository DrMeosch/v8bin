#!/bin/sh
# Succeeds when the PR body (stdin) has a non-empty "## Changelog" section.
# HTML comments are ignored, so the untouched template placeholder counts as empty.

body="$(tr -d '\r' | perl -0pe 's/<!--.*?-->//gs')"

section="$(printf '%s\n' "$body" | awk '
  /^##[ \t]+Changelog[ \t]*$/ { in_section = 1; next }
  /^#+[ \t]/ { in_section = 0 }
  in_section { print }
')"

# A bare type prefix such as "- Added:" with no text does not count.
section="$(printf '%s\n' "$section" | grep -Eiv '^[-*[:space:]]*(added|changed|fixed|removed|security|deprecated)[[:space:]]*:?[[:space:]]*$')"

if [ -z "$(printf '%s' "$section" | tr -d '[:space:]')" ]; then
  echo 'PR body needs a non-empty "## Changelog" section (use "none" for internal-only changes).' >&2
  exit 1
fi
