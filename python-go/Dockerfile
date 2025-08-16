# Use Go base image (multi-arch: amd64, arm64)
FROM golang:1.20-bullseye

# Install Python 3.11
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv wget git build-essential curl && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Install Python dependencies
RUN pip install --no-cache-dir pymongo fastapi uvicorn

# Set environment variables
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"

# Create working directory
WORKDIR /app

# Copy source code and scripts
COPY ./src /app/src
COPY ./scripts /app/scripts

# Default command
CMD ["bash"]

