FROM python:3.12-slim

# Install git (required for GitPython vault operations)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Configure git for vault commits
RUN git config --global user.email "second-brain-bot@localhost" && \
    git config --global user.name "Second Brain"

WORKDIR /app

COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server/ .

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
