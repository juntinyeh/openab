#!/usr/bin/env bash
# local-run-gemini-jira.sh — Run OpenAB Gemini + JIRA + GitHub Discord bot locally
# Usage:
#   bash local-run-gemini-jira.sh          # first run: generates config templates
#   bash local-run-gemini-jira.sh run      # start the bot
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="openab-gemini-jira:local"
CONFIG_FILE="${SCRIPT_DIR}/config-local-gemini-jira.toml"
MCP_FILE="${SCRIPT_DIR}/mcp-local-gemini.json"
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
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
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
    docker build -t "$IMAGE_NAME" -f Dockerfile.gemini-jira "$SCRIPT_DIR"
  else
    echo "==> Image $IMAGE_NAME exists. Rebuild with: docker build -t $IMAGE_NAME -f Dockerfile.gemini-jira ."
  fi
}

###############################################################################
# Actions
###############################################################################
case "$ACTION" in
  init)
    generate_configs
    echo "Config files already exist. Use: bash $0 run"
    ;;
  run)
    generate_configs
    build_image

    MISSING=()
    [[ -z "${DISCORD_BOT_TOKEN:-}" ]]    && MISSING+=("DISCORD_BOT_TOKEN        — Discord bot token")
    [[ -z "${GEMINI_API_KEY:-}" ]]       && MISSING+=("GEMINI_API_KEY           — Google AI Studio API key")
    [[ -z "${ATLASSIAN_SITE_NAME:-}" ]]  && MISSING+=("ATLASSIAN_SITE_NAME     — e.g. 'your-company' from your-company.atlassian.net")
    [[ -z "${ATLASSIAN_USER_EMAIL:-}" ]] && MISSING+=("ATLASSIAN_USER_EMAIL    — Atlassian account email")
    [[ -z "${ATLASSIAN_API_TOKEN:-}" ]]  && MISSING+=("ATLASSIAN_API_TOKEN     — Jira API token (https://id.atlassian.com/manage-profile/security/api-tokens)")
    [[ -z "${GITHUB_TOKEN:-}" ]]         && MISSING+=("GITHUB_TOKEN            — GitHub personal access token")

    if [[ ${#MISSING[@]} -gt 0 ]]; then
      echo ""
      echo "❌ Missing required environment variables:"
      echo ""
      for m in "${MISSING[@]}"; do
        echo "   • $m"
      done
      echo ""
      echo "Example:"
      echo "  DISCORD_BOT_TOKEN=xxx GEMINI_API_KEY=yyy ATLASSIAN_SITE_NAME=your-company \\"
      echo "  ATLASSIAN_USER_EMAIL=you@company.com ATLASSIAN_API_TOKEN=zzz \\"
      echo "  GITHUB_TOKEN=ghp_xxx bash $0 run"
      echo ""
      exit 1
    fi

    echo "==> Starting OpenAB Gemini + JIRA + GitHub Discord bot..."
    docker run -it --rm \
      -e DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
      -e GEMINI_API_KEY="$GEMINI_API_KEY" \
      -e ATLASSIAN_SITE_NAME="$ATLASSIAN_SITE_NAME" \
      -e ATLASSIAN_USER_EMAIL="$ATLASSIAN_USER_EMAIL" \
      -e ATLASSIAN_API_TOKEN="$ATLASSIAN_API_TOKEN" \
      -e GITHUB_TOKEN="$GITHUB_TOKEN" \
      -v "$CONFIG_FILE":/etc/openab/config.toml:ro \
      -v "$MCP_FILE":/home/node/.gemini/settings/mcp.json:ro \
      "$IMAGE_NAME"
    ;;
  *)
    echo "Usage: $0 [run]"
    exit 1
    ;;
esac
