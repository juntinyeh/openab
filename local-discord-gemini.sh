#!/usr/bin/env bash
# local-discord-gemini.sh — Run OpenAB Discord bot with Gemini locally
# Usage: DISCORD_BOT_TOKEN=xxx GEMINI_API_KEY=yyy bash local-discord-gemini.sh
set -euo pipefail

IMAGE_NAME="openab-gemini:local"
CONFIG_FILE="$(cd "$(dirname "$0")" && pwd)/config-local-gemini.toml"

###############################################################################
# Ensure config exists
###############################################################################
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<'EOF'
[discord]
bot_token = "${DISCORD_BOT_TOKEN}"
allowed_channels = ["YOUR_CHANNEL_ID"]

[agent]
command = "gemini"
args = ["--acp"]
working_dir = "/home/node"
env = { GEMINI_API_KEY = "${GEMINI_API_KEY}" }

[pool]
max_sessions = 5
session_ttl_hours = 24

[reactions]
enabled = true
remove_after_reply = false
EOF
  echo "Created $CONFIG_FILE — edit allowed_channels, then re-run."
  exit 0
fi

###############################################################################
# Build image if needed
###############################################################################
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "==> Building $IMAGE_NAME..."
  docker build -t "$IMAGE_NAME" -f Dockerfile.gemini .
else
  echo "==> Image $IMAGE_NAME exists. Use 'docker build -t $IMAGE_NAME -f Dockerfile.gemini .' to rebuild."
fi

###############################################################################
# Run
###############################################################################
: "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN env var}"
: "${GEMINI_API_KEY:?Set GEMINI_API_KEY env var}"

echo "==> Starting OpenAB Discord + Gemini..."
docker run -it --rm \
  -e DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
  -e GEMINI_API_KEY="$GEMINI_API_KEY" \
  -v "$CONFIG_FILE":/etc/openab/config.toml:ro \
  "$IMAGE_NAME"
