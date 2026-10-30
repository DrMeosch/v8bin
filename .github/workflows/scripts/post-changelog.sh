#!/bin/sh
# Appends a merged PR's Changelog lines to the open "Changelog" issue, creating
# and pinning it if missing. Idempotent per PR through a hidden marker comment.
# Env: GH_REPO PR_NUMBER PR_URL MERGE_SHA MERGED_AT SERVER_URL (and GH_TOKEN for gh).
set -eu

dir="$(dirname "$0")"
marker="<!-- changelog-feed pr=$PR_NUMBER -->"

body="$(gh api "repos/$GH_REPO/pulls/$PR_NUMBER" --jq '.body // ""')"
entry="$(printf '%s' "$body" | sh "$dir/changelog-entry.sh" \
  "${MERGED_AT%%T*}" "$PR_URL" "$SERVER_URL/$GH_REPO/commit/$MERGE_SHA")"
if [ -z "$entry" ]; then
  echo "No changelog lines in PR #$PR_NUMBER, skipping."
  exit 0
fi

# Prints the oldest open bot-authored "Changelog" issue number, if any.
oldest_issue() {
  gh issue list --state open --limit 100 --author 'github-actions[bot]' --json number,title \
    --jq '[.[] | select(.title == "Changelog") | .number] | min // empty'
}

issue="$(oldest_issue)"
if [ -z "$issue" ]; then
  url="$(gh issue create --title Changelog \
    --body 'Running log of the Changelog lines of merged pull requests, one comment per PR.')"
  created="${url##*/}"
  # Concurrent first runs may each create an issue: keep the oldest, close ours.
  issue="$(oldest_issue)"
  if [ "$issue" != "$created" ]; then
    gh issue close "$created" --reason "not planned" --comment "Duplicate of #$issue."
  else
    # Pinning needs the GraphQL API and may be refused for this token; the log still works.
    node_id="$(gh api "repos/$GH_REPO/issues/$issue" --jq .node_id)"
    gh api graphql -f query='mutation($id: ID!) { pinIssue(input: {issueId: $id}) { issue { number } } }' \
      -f id="$node_id" >/dev/null || echo "::warning::Could not pin issue #$issue; pin it manually."
  fi
fi

if gh api --paginate "repos/$GH_REPO/issues/$issue/comments" --jq '.[].body' | grep -qF "$marker"; then
  echo "PR #$PR_NUMBER is already in issue #$issue, skipping."
  exit 0
fi
printf '%s\n%s\n' "$marker" "$entry" | gh issue comment "$issue" --body-file -
