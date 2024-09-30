FROM ubuntu:latest

# Install necessary dependencies
RUN apt-get update && apt-get install -y jq git curl

# Copy the action script
COPY manage_todos.sh /manage_todos.sh

# Make the script executable
RUN chmod +x /manage_todos.sh

# Set the entry point for the action
ENTRYPOINT ["/manage_todos.sh"]