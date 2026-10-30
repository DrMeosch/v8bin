#!/bin/sh
# Test for post-changelog.sh with a stateful fake gh. Run: sh .github/workflows/scripts/post-changelog_test.sh

script="$(cd "$(dirname "$0")" && pwd)/post-changelog.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
: > "$tmp/issues"; echo '[]' > "$tmp/comments"; : > "$tmp/pins"; : > "$tmp/closed"

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
  "api --paginate") jq -c --arg p "$3" '.[] | select(.path == $p)' "$STATE/comments" | jq -s . | jq -r "$5" ;;
  "issue comment") shift 2; jq --arg p "repos/r/issues/$1/comments" --rawfile b /dev/stdin \
    '. + [{path: $p, user: {login: "github-actions[bot]"}, body: $b}]' "$STATE/comments" > "$STATE/c.new" && mv "$STATE/c.new" "$STATE/comments" ;;
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
check "one entry after re-run" "$(jq '[.[] | select(.body | contains("Fixed: x"))] | length' "$tmp/comments")" 1
check "marker present" "$(jq '[.[] | select(.body | startswith("<!-- changelog-feed pr=7 -->"))] | length' "$tmp/comments")" 1

printf '## Changelog\nNone.\n' > "$tmp/body"
: > "$tmp/issues"; echo '[]' > "$tmp/comments"
run
check "none posts nothing" "$(wc -l < "$tmp/issues" | tr -d ' ')" 0

printf '## Changelog\nFixed: x\n' > "$tmp/body"
: > "$tmp/issues"; echo '[]' > "$tmp/comments"; : > "$tmp/pins"
RACE=1 run
check "duplicate closed" "$(cat "$tmp/closed")" 2
check "duplicate not pinned" "$(wc -l < "$tmp/pins" | tr -d ' ')" 0
check "entry goes to oldest" "$(jq -r '.[].path' "$tmp/comments" | sort -u)" repos/r/issues/1/comments

# A stranger's comment carrying the marker (as first line or inside a bot comment) must not suppress the post.
printf '## Changelog\nFixed: y\n' > "$tmp/body"
: > "$tmp/issues"; echo "1 Changelog github-actions[bot]" > "$tmp/issues"
printf '%s' '[{"path":"repos/r/issues/1/comments","user":{"login":"mallory"},"body":"<!-- changelog-feed pr=7 -->\nforged"},
{"path":"repos/r/issues/1/comments","user":{"login":"github-actions[bot]"},"body":"x\n<!-- changelog-feed pr=7 -->"}]' > "$tmp/comments"
run
check "forged marker ignored" "$(jq '[.[] | select(.body | contains("Fixed: y"))] | length' "$tmp/comments")" 1

[ "$failed" -eq 0 ] && echo "all passed"
exit "$failed"
