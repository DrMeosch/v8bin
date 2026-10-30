#!/bin/sh
# Succeeds when the PR body (stdin) has a non-empty "## Changelog" section.
# HTML comments are ignored, so the untouched template placeholder counts as empty.

section="$(sh "$(dirname "$0")/changelog-section.sh")"

if [ -z "$(printf '%s' "$section" | tr -d '[:space:]')" ]; then
  echo 'PR body needs a non-empty "## Changelog" section (use "none" for internal-only changes).' >&2
  exit 1
fi
