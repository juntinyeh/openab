#!/usr/bin/env bash
# build.sh — One-time setup: clone repo and build Docker image
# Usage: bash build.sh
set -euo pipefail

REPO_URL="https://github.com/openabdev/openab.git"
REPO_DIR="openab"
IMAGE_NAME="openab-gemini-jira:local"

echo "=== OpenAB Gemini + JIRA + GitHub — Build Script ==="
echo ""

# Step 1: Clone repo if not present
if [[ ! -d "$REPO_DIR" ]]; then
  echo "[1/3] Cloning repository..."
  git clone "$REPO_URL"
else
  echo "[1/3] Repository already exists, skipping clone."
fi

cd "$REPO_DIR"

# Step 2: Copy Dockerfile if not present
if [[ ! -f "Dockerfile.gemini-jira" ]]; then
  echo "[2/3] ERROR: Dockerfile.gemini-jira not found."
  echo "       Place Dockerfile.gemini-jira in the $(pwd) directory and re-run."
  exit 1
else
  echo "[2/3] Dockerfile.gemini-jira found."
fi

# Step 3: Build Docker image
echo "[3/3] Building Docker image (this takes 5-10 minutes the first time)..."
docker build -t "$IMAGE_NAME" -f Dockerfile.gemini-jira .

echo ""
echo "=== Build complete! ==="
echo "Image: $IMAGE_NAME"
echo ""
echo "Next step: bash local-run-gemini-jira.sh"
