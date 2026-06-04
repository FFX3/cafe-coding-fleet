FROM python:3.11-slim-bookworm

# Install Node.js, PostgreSQL client, gcloud SDK, and build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    postgresql-client \
    gcc \
    g++ \
    libpq-dev \
    apt-transport-https \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && echo "deb https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# Create frappe user
RUN useradd -m -s /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# The tarball will be mounted/extracted to /var/frappe/frappe-bench
# gunicorn and other deps come from the venv in the tarball
