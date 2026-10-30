#!/bin/sh
# Prints the "## Changelog" section of a PR body (stdin) without HTML comments
# and without bare type prefixes such as "- Added:". Prints nothing when empty.

tr -d '\r' | perl -0pe 's/<!--.*?-->//gs' | awk '
  /^##[ \t]+Changelog[ \t]*$/ { in_section = 1; next }
  /^#+[ \t]/ { in_section = 0 }
  in_section { print }
' | grep -Eiv '^[-*[:space:]]*(added|changed|fixed|removed|security|deprecated)[[:space:]]*:?[[:space:]]*$'
exit 0
