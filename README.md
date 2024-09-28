# Manage TODO Comments GitHub Action

This GitHub Action automatically manages TODO comments in your code by opening GitHub issues, appending issue IDs to
TODO comments, and resolving issues when TODOs are removed from the code.

## Features

- Automatically creates GitHub issues for new TODO comments.
- Appends issue numbers to TODO comments to prevent duplicate issues.
- Closes issues when the corresponding TODO comments are removed.
- Allows specifying labels for newly created issues.

## Usage

1. Add this action to your workflow file:

   ```yaml
   name: Manage TODOs

   on:
     push:
       branches:
         - main

   jobs:
     manage-todos:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v3

         - name: Manage TODO comments
           uses: datenwissenschaften/manage-todos-action@v1.0.1
           with:
             github-token: ${{ secrets.GITHUB_TOKEN }}
             labels: "todo, help wanted"

