import unittest
from unittest.mock import patch, MagicMock
import manage_todos

class TestManageTodos(unittest.TestCase):

    @patch('subprocess.run')
    def test_find_todos(self, mock_subprocess):
        # Mock the subprocess.run output for grep command
        mock_subprocess.return_value.stdout = "./src/example.py:10:// TODO: Fix this issue\n"
        todos = manage_todos.find_todos()

        # Verify the TODO was found correctly
        self.assertEqual(len(todos), 1)
        self.assertEqual(todos[0], "./src/example.py:10:// TODO: Fix this issue")

    @patch('subprocess.run')
    def test_get_author(self, mock_subprocess):
        # Mock the subprocess.run output for git blame command
        mock_subprocess.return_value.stdout = "author Test Author\n"
        author = manage_todos.get_author("./src/example.py", 10)

        # Verify the author was correctly extracted
        self.assertEqual(author, "Test Author")

    @patch('requests.post')
    def test_create_github_issue_success(self, mock_post):
        # Mock successful GitHub issue creation
        mock_response = MagicMock()
        mock_response.status_code = 201
        mock_response.json.return_value = {"number": 123}
        mock_post.return_value = mock_response

        # Call the function to create an issue
        issue_number = manage_todos.create_github_issue("Test Title", "Test Description")

        # Verify the issue number
        self.assertEqual(issue_number, 123)

    @patch('requests.post')
    def test_create_github_issue_failure(self, mock_post):
        # Mock a failed GitHub issue creation
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.json.return_value = {"message": "Bad Request"}
        mock_post.return_value = mock_response

        # Call the function to create an issue
        issue_number = manage_todos.create_github_issue("Test Title", "Test Description")

        # Verify that no issue number is returned
        self.assertIsNone(issue_number)

    @patch('builtins.open', new_callable=unittest.mock.mock_open, read_data="// TODO: Fix the bug\n")
    @patch('manage_todos.get_author', return_value="Test Author")
    @patch('manage_todos.create_github_issue', return_value=123)
    @patch('subprocess.run')
    def test_process_todos(self, mock_subprocess, mock_create_issue, mock_get_author, mock_open):
        # Mock the subprocess.run output for grep command
        mock_subprocess.return_value.stdout = "./src/example.py:1:// TODO: Fix the bug\n"
        manage_todos.process_todos()

        # Verify that the issue was created and the line was modified
        mock_create_issue.assert_called_once_with("Fix the bug", "Fix the bug\n\n**File:** ./src/example.py\n**Author:** Test Author\n")
        mock_open.assert_called_with("./src/example.py", "w")
        mock_open().writelines.assert_called()

if __name__ == '__main__':
    unittest.main()
