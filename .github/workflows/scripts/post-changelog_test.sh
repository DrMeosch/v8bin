#!/bin/sh
# Test for post-changelog.sh with a stateful fake gh. Run: sh .github/workflows/scripts/post-changelog_test.sh

script="$(cd "$(dirname "$0")" && pwd)/post-changelog.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
: > "$tmp/issues"; : > "$tmp/comments"; : > "$tmp/pins"; : > "$tmp/closed"

cat > "$tmp/bin/gh" <<'STUB'
#!/bin/sh
# Fake gh: state lives in $STATE (issues: "number title author", comments: "number<TAB>body line").
case "$1 $2" in
  "api repos/r/pulls/7") cat "$STATE/body" ;;
  "issue list")
    case "$*" in *"--author github-actions[bot]"*) ;; *) exit 0 ;; esac
    awk '$2 == "Changelog" && $3 == "github-actions[bot]" { print $1 }' "$STATE/issues" | sort -n | head -1 ;;
  "issue close") echo "$3" >> "$STATE/closed" ;;
  "issue create") [ -z "$RACE" ] || echo "1 Changelog github-actions[bot]" >> "$STATE/issues"; n=$(($(wc -l < "$STATE/issues") + 1)); echo "$n Changelog github-actions[bot]" >> "$STATE/issues"; echo "https://x/issues/$n" ;;
  "api graphql") echo pinned >> "$STATE/pins" ;;
  "api --paginate") awk -F"\t" -v p="$3" '$1 == p { print $2 }' "$STATE/comments" ;;
  "issue comment") shift 2; n="$1"; sed "s|^|repos/r/issues/$n/comments\t|" >> "$STATE/comments" ;;
  "api repos/r/issues/"*) echo node ;;
esac
STUB
chmod +x "$tmp/bin/gh"

printf '## Changelog\nFixed: x\n' > "$tmp/body"
run() {
  RACE="${RACE:-}" STATE="$tmp" PATH="$tmp/bin:$PATH" GH_REPO=r PR_NUMBER=7 PR_URL=https://x/pull/7 \
    MERGE_SHA=abc MERGED_AT=2026-01-02T03:04:05Z SERVER_URL=https://x sh "$script" >/dev/null
}

failed=0
check() { [ "$2" = "$3" ] || { echo "FAIL: $1 (want $3, got $2)"; failed=1; }; }

run; run
check "one issue" "$(wc -l < "$tmp/issues" | tr -d ' ')" 1
check "one pin" "$(wc -l < "$tmp/pins" | tr -d ' ')" 1
check "one entry after re-run" "$(grep -c 'Fixed: x' "$tmp/comments")" 1
check "marker present" "$(grep -c 'changelog-feed pr=7' "$tmp/comments")" 1

printf '## Changelog\nNone.\n' > "$tmp/body"
: > "$tmp/issues"; : > "$tmp/comments"
run
check "none posts nothing" "$(wc -l < "$tmp/issues" | tr -d ' ')" 0

printf '## Changelog\nFixed: x\n' > "$tmp/body"
: > "$tmp/issues"; : > "$tmp/comments"; : > "$tmp/pins"
RACE=1 run
check "duplicate closed" "$(cat "$tmp/closed")" 2
check "duplicate not pinned" "$(wc -l < "$tmp/pins" | tr -d ' ')" 0
check "entry goes to oldest" "$(cut -f1 "$tmp/comments" | sort -u)" repos/r/issues/1/comments

[ "$failed" -eq 0 ] && echo "all passed"
exit "$failed"
