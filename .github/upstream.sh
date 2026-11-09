#!/usr/bin/env bash
# Keeps one open issue labeled `upstream` listing the upstream commits main doesn't have yet. A new upstream head
# adds a comment (with a mention, so it e-mails); main catching up closes the issue. Never merges anything.
# Needs GH_TOKEN, GITHUB_REPOSITORY (this fork) and OWNER (who to mention); runs from a full clone of main.
set -euo pipefail

UPSTREAM=joaodutra88/tern-omp-usage

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "https://github.com/$UPSTREAM.git"
git fetch --quiet upstream main
head=$(git rev-parse upstream/main)
count=$(git rev-list --count HEAD..upstream/main)
issue=$(gh api "repos/$GITHUB_REPOSITORY/issues?labels=upstream&state=open&sort=created&direction=asc" -q '.[0].number // empty')

if [ "$count" = 0 ]; then
	if [ -n "$issue" ]; then
		gh issue close "$issue" --repo "$GITHUB_REPOSITORY" --comment "main has every upstream commit now."
	fi
	echo "up to date with $UPSTREAM"
	exit 0
fi

commits=$(git log --reverse --format="- [\`%h\`](https://github.com/$UPSTREAM/commit/%H) %s" HEAD..upstream/main)
title="Upstream has $count new commit$([ "$count" = 1 ] || echo s)"
body=$(cat <<EOF
@$OWNER, [$UPSTREAM](https://github.com/$UPSTREAM) has commits main doesn't have yet.

[Compare main with upstream](https://github.com/$GITHUB_REPOSITORY/compare/main...${UPSTREAM%%/*}:${UPSTREAM##*/}:main)

$commits

To take them: \`git fetch upstream && git merge upstream/main\`, keep this fork's \`SOURCE\`/\`LATEST\` in \`update.luau\`, raise the version in \`plugin.toml\` with a \`CHANGELOG.md\` section, push.

<!-- upstream-head: $head -->
EOF
)

if [ -z "$issue" ]; then
	gh label create upstream --repo "$GITHUB_REPOSITORY" --color 0e8a16 --description "Upstream changes to review" --force
	gh issue create --repo "$GITHUB_REPOSITORY" --label upstream --title "$title" --body "$body"
	exit 0
fi

seen=$(gh issue view "$issue" --repo "$GITHUB_REPOSITORY" --json body -q .body | sed -n 's/.*upstream-head: \([0-9a-f]*\).*/\1/p')
if [ "$seen" != "$head" ]; then
	gh issue edit "$issue" --repo "$GITHUB_REPOSITORY" --title "$title" --body "$body"
	gh issue comment "$issue" --repo "$GITHUB_REPOSITORY" --body "@$OWNER, upstream moved on: $count commit(s) to review now, listed above."
fi
echo "$count upstream commit(s) pending in #$issue"
