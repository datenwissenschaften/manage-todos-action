
# 🚀 Manage TODO Comments GitHub Action

Turn your TODO comments into actionable GitHub issues automatically! This GitHub Action takes the hassle out of managing TODOs in your codebase by converting them into GitHub issues, keeping your development process organized and efficient. Say goodbye to forgotten tasks and untracked code improvements!

## ✨ Key Features

- **Automated Issue Creation**: Automatically opens GitHub issues for new TODO comments in your code, turning vague reminders into trackable tasks.
- **Prevent Duplicate Issues**: Appends issue numbers directly to TODO comments, ensuring that each task is only tracked once.
- **Seamless Issue Resolution**: Closes issues when the corresponding TODO comments are removed, keeping your issue tracker clean and up-to-date.
- **Custom Labels**: Add custom labels like `todo`, `bug`, or `enhancement` to categorize your issues and streamline project management.
- **Context Awareness**: Includes the filename and the original author of the TODO comment in the issue, providing helpful context for each task.

## 📖 How It Works

When you add a TODO comment in your code, this GitHub Action detects it, creates a corresponding issue, and appends the issue number to the TODO. If the TODO is later removed, the action will automatically close the related issue. This ensures your TODOs are tracked, managed, and resolved without any manual effort!

## 🛠️ Usage

Here’s how to get started with the Manage TODO Comments GitHub Action:

1. **Add this action to your workflow file:**

   ```yaml
   name: Manage TODOs

   on:
     push:
       branches:
         - main

   permissions:
     contents: write  # Required for pushing changes back to the repo
     issues: write    # Required to create issues

   jobs:
     manage-todos:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v3

         - name: Manage TODO comments
           uses: datenwissenschaften/manage-todos-action@v1.0.25
           with:
             github-token: ${{ secrets.GITHUB_TOKEN }}
             labels: "todo, help wanted"
   ```

2. **Ensure you have the `GITHUB_TOKEN` set up in your repository’s secrets** to allow the action to authenticate and perform the necessary operations.

## 🚦 Why Use This Action?

Managing TODO comments manually is time-consuming and error-prone. This action streamlines the process by:

- **Boosting Productivity**: Focus on coding while the action tracks and manages TODOs for you.
- **Enhancing Collaboration**: Automatically documents TODOs as GitHub issues, making it easier for team members to see and address them.
- **Maintaining Code Quality**: Regularly track and resolve TODO comments, preventing them from piling up and degrading your codebase.

## 🤖 Action in Action!

Imagine writing a TODO comment like this in your code:

```typescript
// TODO: Refactor this function to improve performance.
// This function is slow and needs to be optimized.
// Investigate potential bottlenecks and implement necessary changes.
```

With this GitHub Action, that comment will automatically turn into a GitHub issue, fully documented with the file name, line number, and author information. The issue will stay open until the TODO is removed, helping you keep track of tasks with minimal effort.

## 💬 Feedback & Contributions

We love feedback! Found a bug, have a feature request, or want to contribute? Feel free to open an issue or submit a pull request.

## 📜 License

This project is licensed under the MIT License.
