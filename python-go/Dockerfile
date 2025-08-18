# Base image: Go + Debian slim
FROM golang:1.20-bullseye

# Install Python, pip, SQLite, and other dependencies
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        wget \
        git \
        build-essential \
        sqlite3 \
        libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache-dir pymongo fastapi uvicorn

# Set working directory
WORKDIR /src

# Copy source and scripts
COPY src /src
COPY scripts /src/scripts

