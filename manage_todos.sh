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

# Convert labels input into JSON array format, trim any leading/trailing spaces
LABELS_JSON=$(echo "$LABELS" | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//' | jq -R . | jq -s .)

# Get the latest commit message to use when closing issues
COMMIT_MESSAGE=$(git log -1 --pretty=%B)

# Get the author of the latest commit
COMMIT_AUTHOR=$(git log -1 --pretty=%an)

echo "Detected TODO comments:"
cat "$TODO_FILE"

# Loop through each TODO and manage issues
while IFS= read -r line; do
    FILE=$(echo "$line" | cut -d ':' -f 1)
    CONTENT=$(echo "$line" | cut -d ':' -f 2-)

    # Filter file endings with .ts
    if [[ "$FILE" != *.ts ]]; then
        echo "File $FILE is not a TypeScript file, skipping."
        continue
    fi

    echo "Processing TODO: $CONTENT in $FILE"

    # Check if TODO already has an issue number
    if [[ "$CONTENT" =~ \[#([0-9]+)\] ]]; then
        ISSUE_NUMBER=${BASH_REMATCH[1]}
        echo "TODO already linked to issue #$ISSUE_NUMBER."
    else
        # Create a new GitHub issue for new TODOs
        echo "Creating a new issue for TODO: $CONTENT"

        # Create the issue body
        BODY="
This issue was automatically created to track the TODO comment in the codebase.

$CONTENT

Commit Message: $COMMIT_MESSAGE

File: $FILE

Author: $COMMIT_AUTHOR
"

        # Escape the TODO content for safe JSON
        ESCAPED_CONTENT=$(echo "$CONTENT" | jq -R .)

        # Escape the body for safe JSON
        ESCAPED_BODY=$(echo "$BODY" | jq -sR .)

        # JSON payload for the GitHub API
        JSON_PAYLOAD="{\"title\": $ESCAPED_CONTENT, \"body\": $ESCAPED_BODY, \"labels\": $LABELS_JSON}"
        echo "Creating issue with payload: $JSON_PAYLOAD"

        ISSUE_RESPONSE=$(curl -X POST \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${GITHUB_REPOSITORY}/issues \
          -d "$JSON_PAYLOAD")

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

                # Get the current issue body from GitHub
                CURRENT_ISSUE_BODY=$(curl -s \
                  -H "Authorization: token $GITHUB_TOKEN" \
                  -H "Accept: application/vnd.github.v3+json" \
                  https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/$ISSUE_NUMBER | jq -r .body)

                # Append the closure message to the current issue body
                UPDATED_BODY="
$CURRENT_ISSUE_BODY

### UPDATE

Issue closed because the TODO was removed.

Commit Message: $COMMIT_MESSAGE
"

                # Close the issue on GitHub with the updated body
                curl -X PATCH \
                  -H "Authorization: token $GITHUB_TOKEN" \
                  -H "Accept: application/vnd.github.v3+json" \
                  https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/$ISSUE_NUMBER \
                  -d "{\"state\": \"closed\", \"body\": $(jq -R <<<"$UPDATED_BODY")}"
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