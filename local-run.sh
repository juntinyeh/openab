#!/usr/bin/env bash
# local-run.sh — Build and run OpenAB Kiro+JIRA Discord bot locally
# Usage:
#   bash local-run.sh              # first run: generates config + mcp.json templates
#   bash local-run.sh login        # one-time kiro-cli auth
#   bash local-run.sh run          # start the bot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="openab-kiro-jira:local"
VOLUME_NAME="openab-kiro-jira-data"
CONFIG_FILE="${SCRIPT_DIR}/config-local-kiro-jira.toml"
MCP_FILE="${SCRIPT_DIR}/mcp-local-jira.json"
ACTION="${1:-init}"

###############################################################################
# Generate config templates if missing
###############################################################################
generate_configs() {
  local generated=0

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<'EOF'
[discord]
bot_token = "${DISCORD_BOT_TOKEN}"
allowed_channels = ["YOUR_CHANNEL_ID"]

[agent]
command = "kiro-cli"
args = ["acp", "--trust-all-tools"]
working_dir = "/home/agent"

[pool]
max_sessions = 5
session_ttl_hours = 24

[reactions]
enabled = true
remove_after_reply = false
EOF
    echo "Created $CONFIG_FILE"
    generated=1
  fi

  if [[ ! -f "$MCP_FILE" ]]; then
    cat > "$MCP_FILE" <<'EOF'
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@aashari/mcp-server-atlassian-jira"],
      "env": {
        "ATLASSIAN_SITE_NAME": "${ATLASSIAN_SITE_NAME}",
        "ATLASSIAN_USER_EMAIL": "${ATLASSIAN_USER_EMAIL}",
        "ATLASSIAN_API_TOKEN": "${ATLASSIAN_API_TOKEN}"
      }
    }
  }
}
EOF
    echo "Created $MCP_FILE"
    generated=1
  fi

  if [[ $generated -eq 1 ]]; then
    echo ""
    echo "Edit the files above, then re-run: bash $0 run"
    exit 0
  fi
}

###############################################################################
# Build image if needed
###############################################################################
build_image() {
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "==> Building $IMAGE_NAME..."
    docker build -t "$IMAGE_NAME" -f Dockerfile.kiro-jira "$SCRIPT_DIR"
  else
    echo "==> Image $IMAGE_NAME exists. Rebuild with: docker build -t $IMAGE_NAME -f Dockerfile.kiro-jira ."
  fi
}

###############################################################################
# Actions
###############################################################################
case "$ACTION" in
  init)
    generate_configs
    echo "Config files already exist. Use: bash $0 [login|run]"
    ;;
  login)
    build_image
    docker volume create "$VOLUME_NAME" >/dev/null 2>&1 || true
    echo "==> Kiro CLI login (device flow)..."
    docker run -it \
      -v "$VOLUME_NAME":/home/agent/.local/share/kiro-cli \
      -v "$VOLUME_NAME":/home/agent/.kiro \
      "$IMAGE_NAME" \
      kiro-cli login --use-device-flow
    ;;
  run)
    generate_configs
    build_image
    docker volume create "$VOLUME_NAME" >/dev/null 2>&1 || true

    : "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN}"
    : "${ATLASSIAN_SITE_NAME:?Set ATLASSIAN_SITE_NAME (e.g. your-company for your-company.atlassian.net)}"
    : "${ATLASSIAN_USER_EMAIL:?Set ATLASSIAN_USER_EMAIL}"
    : "${ATLASSIAN_API_TOKEN:?Set ATLASSIAN_API_TOKEN}"

    echo "==> Starting OpenAB Kiro+JIRA Discord bot..."
    docker run -it --rm \
      -e DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
      -e ATLASSIAN_SITE_NAME="$ATLASSIAN_SITE_NAME" \
      -e ATLASSIAN_USER_EMAIL="$ATLASSIAN_USER_EMAIL" \
      -e ATLASSIAN_API_TOKEN="$ATLASSIAN_API_TOKEN" \
      -v "$CONFIG_FILE":/etc/openab/config.toml:ro \
      -v "$MCP_FILE":/home/agent/.kiro/settings/mcp.json:ro \
      -v "$VOLUME_NAME":/home/agent/.local/share/kiro-cli \
      "$IMAGE_NAME"
    ;;
  *)
    echo "Usage: $0 [login|run]"
    exit 1
    ;;
esac
