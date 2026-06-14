#!/usr/bin/env bash
# Usage: ./fetch.sh <pat> <url>

set -e

PAT="${1:?Usage: $0 <pat> <url>}"
URL="${2:?Usage: $0 <pat> <url>}"
REPO="adatskov-wcpss/innocent-claude"
BRANCH="main"
CONFIG_FILE="config/fetch-url.txt"

echo "📤 Pushing URL to repo..."

SHA=$(curl -s -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/$CONFIG_FILE" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])")

curl -s -X PUT -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/$CONFIG_FILE" \
  -d "{
    \"message\": \"fetch: $URL\",
    \"content\": \"$(echo -n "$URL" | base64 -w0)\",
    \"sha\": \"$SHA\",
    \"branch\": \"$BRANCH\"
  }" > /dev/null

echo "⏳ Waiting for Actions workflow to complete..."

for i in $(seq 1 30); do
  sleep 5
  RESPONSE=$(curl -s -H "Authorization: token $PAT" \
    "https://api.github.com/repos/$REPO/actions/runs?per_page=1")
  STATUS=$(echo "$RESPONSE" | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['status'])")
  CONCLUSION=$(echo "$RESPONSE" | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['conclusion'])")

  echo "  [$i] status: $STATUS / $CONCLUSION"

  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" != "success" ]]; then
      echo "❌ Workflow failed: $CONCLUSION"
      exit 1
    fi
    break
  fi
done

echo "✅ Workflow done! Downloading and cleaning up..."

# Find and download the fetched file, then delete it from the repo
FILES=$(curl -s -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/config/" \
  | python3 -c "
import json, sys
files = json.load(sys.stdin)
for f in files:
    if f['name'] != 'fetch-url.txt':
        print(f['name'], f['download_url'], f['sha'])
")

while IFS=' ' read -r name dl_url sha; do
  echo "📥 Downloading: $name"
  curl -s -L -o "$name" "$dl_url"
  echo "🗑️  Deleting from repo: $name"
  curl -s -X DELETE -H "Authorization: token $PAT" \
    "https://api.github.com/repos/$REPO/contents/config/$name" \
    -d "{\"message\": \"cleanup: remove $name\", \"sha\": \"$sha\", \"branch\": \"$BRANCH\"}" > /dev/null
  echo "✅ Saved locally: $(pwd)/$name"
done <<< "$FILES"
