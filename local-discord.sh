#!/usr/bin/env bash
# local-discord.sh — Build and run OpenAB Discord bot locally via Docker
# Usage: DISCORD_BOT_TOKEN=xxx bash local-discord.sh [--agent kiro|gemini] [login|run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT="kiro"

# Parse --agent flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    *) break ;;
  esac
done
ACTION="${1:-run}"

###############################################################################
# Agent-specific settings
###############################################################################
case "$AGENT" in
  kiro)
    IMAGE_NAME="openab:local"
    DOCKERFILE="Dockerfile"
    WORK_DIR="/home/agent"
    AGENT_CMD='command = "kiro-cli"'
    AGENT_ARGS='args = ["acp", "--trust-all-tools"]'
    AGENT_ENV=""
    ;;
  gemini)
    IMAGE_NAME="openab-gemini:local"
    DOCKERFILE="Dockerfile.gemini"
    WORK_DIR="/home/node"
    AGENT_CMD='command = "gemini"'
    AGENT_ARGS='args = ["--acp"]'
    AGENT_ENV='env = { GEMINI_API_KEY = "${GEMINI_API_KEY}" }'
    ;;
  *) echo "Unknown agent: $AGENT (supported: kiro, gemini)"; exit 1 ;;
esac

VOLUME_NAME="openab-local-${AGENT}"
CONFIG_FILE="${SCRIPT_DIR}/config-local-${AGENT}.toml"

###############################################################################
# Ensure config exists
###############################################################################
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<EOF
[discord]
bot_token = "\${DISCORD_BOT_TOKEN}"
allowed_channels = ["YOUR_CHANNEL_ID"]

[agent]
${AGENT_CMD}
${AGENT_ARGS}
working_dir = "${WORK_DIR}"
${AGENT_ENV}

[pool]
max_sessions = 5
session_ttl_hours = 24

[reactions]
enabled = true
remove_after_reply = false
EOF
  echo "Created $CONFIG_FILE — edit allowed_channels before running."
  exit 0
fi

###############################################################################
# Build image (skip if already built)
###############################################################################
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "==> Building $IMAGE_NAME (first time takes a while)..."
  docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" .
else
  echo "==> Image $IMAGE_NAME exists. Use 'docker build -t $IMAGE_NAME -f $DOCKERFILE .' to rebuild."
fi

###############################################################################
# Create persistent volume for auth
###############################################################################
docker volume create "$VOLUME_NAME" >/dev/null 2>&1 || true

###############################################################################
# Actions
###############################################################################
case "$ACTION" in
  login)
    case "$AGENT" in
      kiro)
        echo "==> Logging in to Kiro CLI (device flow)..."
        docker run -it \
          -v "$VOLUME_NAME":/home/agent/.local/share/kiro-cli \
          -v "$VOLUME_NAME":/home/agent/.kiro \
          "$IMAGE_NAME" \
          kiro-cli login --use-device-flow
        ;;
      gemini)
        echo "Gemini uses GEMINI_API_KEY — no login needed. Set the env var at run time."
        ;;
    esac
    ;;
  run)
    : "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN env var}"
    ENV_ARGS=(-e DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN")
    VOL_ARGS=(-v "$CONFIG_FILE":/etc/openab/config.toml:ro)

    case "$AGENT" in
      kiro)
        VOL_ARGS+=(-v "$VOLUME_NAME":/home/agent/.local/share/kiro-cli)
        VOL_ARGS+=(-v "$VOLUME_NAME":/home/agent/.kiro)
        ;;
      gemini)
        : "${GEMINI_API_KEY:?Set GEMINI_API_KEY env var}"
        ENV_ARGS+=(-e GEMINI_API_KEY="$GEMINI_API_KEY")
        ;;
    esac

    echo "==> Starting OpenAB Discord bot (agent=$AGENT)..."
    docker run -it --rm "${ENV_ARGS[@]}" "${VOL_ARGS[@]}" "$IMAGE_NAME"
    ;;
  *)
    echo "Usage: $0 [--agent kiro|gemini] [login|run]"
    exit 1
    ;;
esac
