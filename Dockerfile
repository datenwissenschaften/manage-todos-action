FROM python:3.9-slim

# Install required packages
RUN apt-get update && apt-get install -y git grep curl jq

# Install python packages
RUN pip install requests

# Copy the main Python script
COPY manage_todos.py /manage_todos.py

# Set the entrypoint to run the Python script
ENTRYPOINT ["python3", "/manage_todos.py"]
