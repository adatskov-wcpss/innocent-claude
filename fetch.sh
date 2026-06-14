#!/usr/bin/env bash
# Usage: ./fetch.sh <url>

set -e

PAT="${GITHUB_PAT:?Error: GITHUB_PAT env var not set}"
REPO="adatskov-wcpss/innocent-claude"
BRANCH="main"
CONFIG_FILE="config/fetch-url.txt"

if [[ -z "$1" ]]; then
  echo "Usage: $0 <url>"
  exit 1
fi

URL="$1"
echo "📤 Pushing URL to repo..."

# Get current file SHA (needed for update)
SHA=$(curl -s -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/$CONFIG_FILE" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])")

# Push the URL to config/fetch-url.txt
curl -s -X PUT -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/$CONFIG_FILE" \
  -d "{
    \"message\": \"fetch: $URL\",
    \"content\": \"$(echo -n "$URL" | base64 -w0)\",
    \"sha\": \"$SHA\",
    \"branch\": \"$BRANCH\"
  }" > /dev/null

echo "⏳ Waiting for Actions workflow to complete..."

# Poll for the latest run to finish
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

echo "✅ Done! Fetching file from repo..."

# Find the new file in config/ (anything that's not fetch-url.txt)
FILES=$(curl -s -H "Authorization: token $PAT" \
  "https://api.github.com/repos/$REPO/contents/config/" \
  | python3 -c "
import json, sys
files = json.load(sys.stdin)
for f in files:
    if f['name'] != 'fetch-url.txt':
        print(f['name'], f['download_url'])
")

echo ""
echo "📁 Files in config/:"
while IFS=' ' read -r name dl_url; do
  echo "  $name"
  echo "  ↳ $dl_url"
done <<< "$FILES"

