#!/bin/sh
# Unit test for changelog-entry.sh. Run: sh .github/workflows/scripts/changelog-entry_test.sh

script="$(dirname "$0")/changelog-entry.sh"
failed=0

run() { printf '%s' "$1" | sh "$script" 2026-01-02 https://x/pull/7 https://x/commit/abc; }

expect() {
  name="$1" body="$2" want="$3"
  got="$(run "$body")"
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name"
    printf 'want: %s\ngot:  %s\n' "$want" "$got"
    failed=1
  fi
}

head='**2026-01-02** - https://x/pull/7 - [merge commit](https://x/commit/abc)'

expect "lines" "## Summary
s

## Changelog
- Added: a thing
- Fixed: b

## Notes
n" "$head

- Added: a thing
- Fixed: b"
expect "none" "## Changelog
none" ""
expect "None with period" "## Changelog
None." ""
expect "missing section" "## Summary
s" ""
expect "untouched template" "$(cat "$(dirname "$0")/../../pull_request_template.md")" ""
expect "mentions defused" "## Changelog
Fixed: thanks @someone" "$head

Fixed: thanks @​someone"

[ "$failed" -eq 0 ] && echo "all passed"
exit "$failed"
