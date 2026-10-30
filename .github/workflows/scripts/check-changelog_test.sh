#!/bin/sh
# Unit test for check-changelog.sh. Run: sh .github/workflows/scripts/check-changelog_test.sh

script="$(dirname "$0")/check-changelog.sh"
failed=0

expect() {
  want="$1" name="$2" body="$3"
  printf '%s' "$body" | sh "$script" >/dev/null 2>&1
  got=$?
  [ "$got" -ne 0 ] && got=1
  if [ "$got" -ne "$want" ]; then
    echo "FAIL: $name (want exit $want, got $got)"
    failed=1
  fi
}

expect 0 "text entry" "## Changelog

Fixed: crash on startup"
expect 0 "none" "## Changelog
none"
expect 0 "followed by another section" "## Changelog
Added: x

## Notes
y"
expect 0 "CRLF line endings" "## Changelog
none
"
expect 1 "missing section" "## Summary
hello"
expect 1 "empty body" ""
expect 1 "empty section" "## Changelog

## Notes
y"
expect 1 "comment-only placeholder" "## Changelog
<!-- one or two lines
or none -->
"
expect 1 "heading only at end" "## Changelog"
expect 1 "similar heading" "## Changelog notes
text"

[ "$failed" -eq 0 ] && echo "all passed"
exit "$failed"
