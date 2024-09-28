FROM python:3.9-slim

RUN apt-get update && apt-get install -y git grep curl jq
RUN pip install requests

COPY manage_todos.py /manage_todos.py

ENTRYPOINT ["python3", "/manage_todos.py"]
