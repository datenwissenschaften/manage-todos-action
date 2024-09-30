import os
import subprocess
import re
import requests

# Configuration variables
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
LABELS = os.getenv("LABELS", "")
REPO = os.getenv("GITHUB_REPOSITORY")
FILES_TO_SEARCH = ["./"]
FILE_ENDINGS = [".ts"]  # Adjust to match the file types to check
KEY_WORDS = ["// TODO", "//TODO"]

# Prepare labels in a correct format as a list of strings
labels_list = [label.strip() for label in LABELS.split(",") if label.strip()]

# Define a function to find TODO comments with line numbers
def find_todos():
    todos = []
    for key_word in KEY_WORDS:
        for filepath in FILES_TO_SEARCH:
            # Run grep to find TODO comments with line numbers
            result = subprocess.run(
                ["grep", "-rn", key_word, filepath], capture_output=True, text=True
            )
            todos.extend(result.stdout.strip().split("\n"))
    return [todo for todo in todos if todo]  # Filter out empty lines

# Function to extract author of a specific line using git blame
def get_author(filepath, line_number):
    result = subprocess.run(
        ["git", "blame", "-L", f"{line_number},{line_number}", filepath, "--line-porcelain"],
        capture_output=True,
        text=True
    )
    author_match = re.search(r"^author (.+)$", result.stdout, re.MULTILINE)
    return author_match.group(1) if author_match else "Unknown Author"

# Function to create a GitHub issue
def create_github_issue(title, description):
    url = f"https://api.github.com/repos/{REPO}/issues"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    payload = {
        "title": title,
        "body": description,
        "labels": labels_list  # Correctly formatted labels list
    }
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 201:
        issue_number = response.json()["number"]
        print(f"Issue created successfully with number #{issue_number}.")
        return issue_number
    else:
        print(f"Failed to create an issue. Response: {response.json()}")
        return None

# Function to close a GitHub issue
def close_github_issue(issue_number, commit_message):
    url = f"https://api.github.com/repos/{REPO}/issues/{issue_number}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    payload = {
        "state": "closed",
        "body": f"Issue closed because the corresponding TODO was removed. \n\nCommit Message: {commit_message}"
    }
    response = requests.patch(url, headers=headers, json=payload)
    if response.status_code == 200:
        print(f"Issue #{issue_number} closed successfully.")
    else:
        print(f"Failed to close issue #{issue_number}. Response: {response.json()}")

# Main function to process TODO comments
def process_todos():
    # Get the current commit message
    commit_message = subprocess.check_output(["git", "log", "-1", "--pretty=%B"]).strip().decode('utf-8')

    # Dictionary to track existing TODOs and their associated issue numbers
    existing_todos = {}

    # Read the todos.txt file to load previously tracked TODOs
    todos_file = "todos.txt"
    if os.path.exists(todos_file):
        with open(todos_file, "r") as file:
            for line in file.readlines():
                if " [#" in line:
                    todo, issue = line.strip().rsplit(" [#", 1)
                    issue_number = issue.strip("]")
                    existing_todos[todo.strip()] = issue_number

    # Find current TODO comments in the code
    current_todos = find_todos()

    # Track remaining TODOs that still exist
    remaining_todos = set()

    for line in current_todos:
        # Extract filepath, line number, and content
        match = re.match(r"^(.*):(\d+):(.*)$", line)
        if not match:
            print(f"Skipping invalid TODO line: {line}")
            continue

        filepath, line_number, content = match.groups()
        line_number = int(line_number)

        # Skip if file is not of the specified type
        if not filepath.endswith(tuple(FILE_ENDINGS)):
            print(f"Skipping file: {line}")
            continue

        print(f"Processing TODO: {content.strip()} in {filepath} at line {line_number}")

        # Check if TODO already has an issue number
        if re.search(r"\[#\d+\]", content):
            print(f"TODO already linked to an issue.")
            remaining_todos.add(content.strip())
            continue

        # Extract the title and subsequent lines for description
        title = content.strip().replace("// TODO:", "").strip()
        description = ""

        # Read subsequent lines starting with // as description
        with open(filepath, "r") as file:
            lines = file.readlines()
            for i in range(line_number, len(lines)):
                desc_line = lines[i].strip()
                if desc_line.startswith("//"):
                    description += desc_line.replace("//", "").strip() + "\n"
                else:
                    break

        # Get author information using git blame
        author = get_author(filepath, line_number)

        # Append filename and author details to the description
        description += f"\n**File:** {filepath}\n**Author:** {author}\n"

        # Create a new GitHub issue
        issue_number = create_github_issue(title, description)

        # Append the issue number to the TODO line if issue creation was successful
        if issue_number:
            lines[line_number - 1] = f"{lines[line_number - 1].strip()} [#{issue_number}]\n"
            with open(filepath, "w") as file:
                file.writelines(lines)
            remaining_todos.add(content.strip())

    # Check if any TODOs were removed and close their corresponding issues
    for todo, issue_number in existing_todos.items():
        if todo not in remaining_todos:
            print(f"TODO '{todo}' was removed. Closing issue #{issue_number}.")
            close_github_issue(issue_number, commit_message)

    # Save the updated remaining TODOs to todos.txt
    with open(todos_file, "w") as file:
        for todo in remaining_todos:
            file.write(f"{todo} [#{existing_todos.get(todo, 'NEW')}]\n")

# Run the main function
if __name__ == "__main__":
    process_todos()