#!/bin/bash

set -e

# Define a temporary file to store TODO comments
TODO_FILE="todos.txt"

# Find all TODO comments, excluding the file where results are saved
grep -r "// TODO:" . --exclude="$TODO_FILE" > "$TODO_FILE" || true
grep -r "//TODO:" . --exclude="$TODO_FILE" >> "$TODO_FILE" || true
grep -r "# TODO:" . --exclude="$TODO_FILE" >> "$TODO_FILE" || true
grep -r "#TODO:" . --exclude="$TODO_FILE" >> "$TODO_FILE" || true


# Exit if no TODO comments are found
if [ ! -s "$TODO_FILE" ]; then
    echo "No TODOs found."
    exit 0
fi

# Convert labels input into JSON array format
LABELS_JSON=$(echo "$LABELS" | jq -R 'split(",")')

# Loop through each TODO and manage issues
while IFS= read -r line; do
    FILE=$(echo "$line" | cut -d ':' -f 1)
    CONTENT=$(echo "$line" | cut -d ':' -f 2-)

    # Check if TODO already has an issue number
    if [[ "$CONTENT" =~ \[#([0-9]+)\] ]]; then
        ISSUE_NUMBER=${BASH_REMATCH[1]}
        # Check the status of the issue
        ISSUE_STATUS=$(curl -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/$ISSUE_NUMBER | jq -r .state)

        # Close the issue if the TODO is removed
        if [[ "$ISSUE_STATUS" == "open" ]] && ! grep -qF "$CONTENT" "$FILE"; then
            curl -X PATCH \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/$ISSUE_NUMBER \
              -d "{\"state\": \"closed\", \"body\": \"Resolved: TODO removed from code.\"}"
        fi
    else
        # Create a new GitHub issue for new TODOs
        ISSUE_RESPONSE=$(curl -X POST \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${GITHUB_REPOSITORY}/issues \
          -d "{\"title\": \"TODO found in code\", \"body\": \"$CONTENT\", \"labels\": $LABELS_JSON}")

        ISSUE_NUMBER=$(echo $ISSUE_RESPONSE | jq -r .number)

        # Append the issue number to the TODO line if the issue was created
        if [ "$ISSUE_NUMBER" != "null" ]; then
            sed -i "s|$CONTENT|$CONTENT [#$ISSUE_NUMBER]|" "$FILE"
        fi
    fi
done < "$TODO_FILE"

# Commit the updated TODOs
git config --global user.name "GitHub Action"
git config --global user.email "actions@github.com"
git add .
git commit -m "Update TODO comments with issue numbers"
git push