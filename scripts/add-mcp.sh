#!/usr/bin/env bash
# 将 MCP 配置追加到 mcp/user-servers.json
#
# 用法:
#   add-mcp.sh <name> <json-config>
#
# 示例:
#   add-mcp.sh github '{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN}"}}'

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_FILE="${REPO}/mcp/user-servers.json"

usage() {
  echo "用法: $0 <name> '<json-config>'"
  echo ""
  echo "示例:"
  echo "  $0 github '{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@modelcontextprotocol/server-github\"],\"env\":{\"GITHUB_PERSONAL_ACCESS_TOKEN\":\"\${GITHUB_PERSONAL_ACCESS_TOKEN}\"}}'"
  exit 1
}

[[ $# -eq 2 ]] || usage

NAME="$1"
CONFIG="$2"

command -v jq >/dev/null 2>&1 || { echo "错误: 需要 jq"; exit 1; }

echo "$CONFIG" | jq empty

if [[ ! -f "$MCP_FILE" ]]; then
  echo '{"mcpServers":{}}' > "$MCP_FILE"
fi

tmp="$(mktemp)"
jq --arg name "$NAME" --argjson cfg "$CONFIG" \
  '.mcpServers[$name] = $cfg' \
  "$MCP_FILE" > "$tmp"
mv "$tmp" "$MCP_FILE"

echo "已添加 MCP 配置: ${NAME}"
echo "  文件: ${MCP_FILE}"
echo ""
echo "使配置生效:"
echo "  ${REPO}/bootstrap.sh"
echo ""
echo "提交到 Git:"
echo "  cd ${REPO} && git add mcp/user-servers.json && git commit -m \"add mcp: ${NAME}\""
