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

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Install Python packages
RUN pip install --no-cache-dir pymongo fastapi uvicorn

# Install sqlite3 in the apios-sqlite container
RUN apt-get update && apt-get install -y sqlite3

# Set working directory
WORKDIR /src

# Copy source and scripts
COPY src /src
COPY scripts /src/scripts

