# Use official Python runtime as base image
FROM python:3.11-slim

# Set environment variables for Python
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# 1. Define a build-time argument for the port
ARG BUILD_APP_PORT=8000

# 2. Set the runtime environment variable from the build argument
ENV APP_PORT=${BUILD_APP_PORT}

# Set working directory in container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file first (for better Docker caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY *.py ./

# Expose the port the app runs on (uses the ENV value)
EXPOSE ${APP_PORT}

# Use the ENV variable in the CMD
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${APP_PORT}"]