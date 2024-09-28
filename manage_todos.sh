#!/bin/bash

set -e

# Configure Git to treat the current workspace as a safe directory inside the Docker container
git config --global --add safe.directory /github/workspace

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

echo "Detected TODO comments:"
cat "$TODO_FILE"

# Loop through each TODO and manage issues
while IFS= read -r line; do
    FILE=$(echo "$line" | cut -d ':' -f 1)
    LINE_NUMBER=$(echo "$line" | cut -d ':' -f 2)
    CONTENT=$(echo "$line" | cut -d ':' -f 3-)

    echo "Processing TODO: $CONTENT in $FILE at line $LINE_NUMBER"

    # Check if TODO already has an issue number
    if [[ "$CONTENT" =~ \[#([0-9]+)\] ]]; then
        ISSUE_NUMBER=${BASH_REMATCH[1]}
        echo "TODO already linked to issue #$ISSUE_NUMBER."
    else
        # Extract the title from the first line after TODO
        TITLE=$(echo "$CONTENT" | sed 's/^[[:space:]]*\/\/\s*TODO:\?//')

        # Find subsequent lines that start with // and treat them as description
        DESCRIPTION=""
        NEXT_LINE_NUMBER=$((LINE_NUMBER + 1))
        while IFS= read -r desc_line; do
            desc_content=$(echo "$desc_line" | grep "^//" | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
            if [ ! -z "$desc_content" ]; then
                DESCRIPTION+="$desc_content"$'\n'
            else
                break
            fi
            NEXT_LINE_NUMBER=$((NEXT_LINE_NUMBER + 1))
        done < <(tail -n +$NEXT_LINE_NUMBER "$FILE")

        # Get the author information for the specific TODO line using git blame
        AUTHOR=$(git blame -L "$LINE_NUMBER","$LINE_NUMBER" "$FILE" --line-porcelain | grep "^author " | cut -d ' ' -f 2-)

        # Append filename and author details to the description
        DESCRIPTION+="\n**File:** $FILE\n"
        DESCRIPTION+="**Author:** $AUTHOR\n"

        # Create a new GitHub issue for new TODOs
        echo "Creating a new issue with title: $TITLE"
        echo -e "Description: $DESCRIPTION"

        ISSUE_RESPONSE=$(curl -X POST \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${GITHUB_REPOSITORY}/issues \
          -d "{\"title\": \"$TITLE\", \"body\": \"$DESCRIPTION\", \"labels\": $LABELS_JSON}")

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

# Commit the updated TODOs
git config --global user.name "GitHub Action"
git config --global user.email "actions@github.com"
git add .
git commit -m "Update TODO comments with issue numbers"
git push