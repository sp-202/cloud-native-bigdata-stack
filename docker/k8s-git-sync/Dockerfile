# Multi-stage build to get git-sync binary and create a lightweight image with mc
FROM registry.k8s.io/git-sync/git-sync:v4.2.3 AS source

# Use Ubuntu as the base for the final image to ensure we have a shell and package manager
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies: git (required for git-sync), curl (for downloading mc), and ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy git-sync binary from the official image
COPY --from=source /git-sync /usr/local/bin/git-sync

# Install mc (MinIO Client) - Dynamic Architecture
ARG TARGETARCH
RUN curl https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
    --create-dirs \
    -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

# Copy sync hook script
COPY sync-hook.sh /usr/local/bin/sync-hook.sh
RUN chmod +x /usr/local/bin/sync-hook.sh

# Create a non-root user for security (optional but good practice, git-sync usually runs as non-root)
# However, for simplicity and ensuring mc/git permissions, running as root is often easier in these custom sidecars unless strict PSPs exist.
# The original git-sync runs as root (UID 0) in the user's yaml:
# securityContext:
#   runAsUser: 0
# So we will stick to root or ensure strict permissions.
# We will verify /usr/local/bin is in PATH (it is).

# Entrypoint should be git-sync, but let's leave it flexible or set it to git-sync
ENTRYPOINT ["/usr/local/bin/git-sync"]
