#!/bin/bash

set -e

# Configure Git to treat the current workspace as a safe directory
git config --global --add safe.directory /github/workspace

# Set Git user identity (needed in CI environments)
git config --global user.name "GitHub Action"
git config --global user.email "actions@github.com"

# Define a temporary file to store TODO comments
TODO_FILE="todos.txt"

# Find all TODO comments, excluding the file where results are saved
grep -r "// TODO:" . --exclude="$TODO_FILE" > "$TODO_FILE" || true
grep -r "//TODO:" . --exclude="$TODO_FILE" >> "$TODO_FILE" || true

# Exit if no TODO comments are found
if [ ! -s "$TODO_FILE" ]; then
    echo "No TODOs found."
    exit 0
fi

# Convert labels input into JSON array format
LABELS_JSON=$(echo "$LABELS" | jq -R 'split(",")')

# Get the latest commit message to use when closing issues
COMMIT_MESSAGE=$(git log -1 --pretty=%B)

echo "Detected TODO comments:"
cat "$TODO_FILE"

# Loop through each TODO and manage issues
while IFS= read -r line; do
    FILE=$(echo "$line" | cut -d ':' -f 1)
    CONTENT=$(echo "$line" | cut -d ':' -f 2-)

    echo "Processing TODO: $CONTENT in $FILE"

    # Check if TODO already has an issue number
    if [[ "$CONTENT" =~ \[#([0-9]+)\] ]]; then
        ISSUE_NUMBER=${BASH_REMATCH[1]}
        echo "TODO already linked to issue #$ISSUE_NUMBER."
    else
        # Create a new GitHub issue for new TODOs
        echo "Creating a new issue for TODO: $CONTENT"

        BODY="This issue was automatically created to track the TODO comment in the codebase.\\n\\nCommit Message: $COMMIT_MESSAGE\\n\\nFile: $FILE\\n\\nTODO: $CONTENT"

        ISSUE_RESPONSE=$(curl -X POST \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${GITHUB_REPOSITORY}/issues \
          -d "{\"title\": \"$CONTENT\", \"body\": \"$BODY\", \"labels\": $LABELS_JSON}")

        ISSUE_NUMBER=$(echo $ISSUE_RESPONSE | jq -r .number)

        # Check if the issue was created successfully
        if [ "$ISSUE_NUMBER" != "null" ]; then
            echo "Issue created successfully with number #$ISSUE_NUMBER."
            # Append the issue number to the TODO line
            sed -i "s|$CONTENT|$CONTENT [#$ISSUE_NUMBER]|" "$FILE"
        else
            echo "Failed to create an issue. Response: $ISSUE_RESPONSE"
        fi
    fi
done < "$TODO_FILE"

# Close GitHub issues if TODOs are removed
if [ -f "$TODO_FILE" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ \[#([0-9]+)\] ]]; then
            ISSUE_NUMBER=${BASH_REMATCH[1]}
            # Check if the TODO still exists in the codebase
            if ! grep -q "\[$ISSUE_NUMBER\]" "$TODO_FILE"; then
                echo "TODO with issue #$ISSUE_NUMBER has been removed, closing the issue."

                # Close the issue on GitHub
                curl -X PATCH \
                  -H "Authorization: token $GITHUB_TOKEN" \
                  -H "Accept: application/vnd.github.v3+json" \
                  https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/$ISSUE_NUMBER \
                  -d "{\"state\": \"closed\", \"body\": \"Issue closed because the TODO was removed.\\n\\nCommit Message: $COMMIT_MESSAGE\"}"
            fi
        fi
    done < "$TODO_FILE"
fi

# Check if there are changes to commit
if git diff --quiet; then
    echo "No changes to commit."
else
    # Stage changes
    git add .

    # Commit changes
    git commit -m "Update TODO comments with issue numbers"

    # Pull and rebase if necessary before pushing
    git pull --rebase

    # Push changes
    git push
fi