#!/usr/bin/env bash
# 将 MCP 配置追加到 mcp/user-servers.toml
#
# 用法:
#   add-mcp.sh <name> <command> [args...]
#   add-mcp.sh --url <name> <url> [--bearer-token-env ENV_VAR]
#
# 示例:
#   add-mcp.sh github npx -y @modelcontextprotocol/server-github
#   add-mcp.sh --url docs https://example.com/mcp --bearer-token-env DOCS_TOKEN
#
# 也可直接编辑 mcp/user-servers.toml，然后运行 bootstrap.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_FILE="${REPO}/mcp/user-servers.toml"

usage() {
  echo "用法:"
  echo "  $0 <name> <command> [args...]"
  echo "  $0 --url <name> <url> [--bearer-token-env ENV_VAR]"
  exit 1
}

[[ $# -ge 2 ]] || usage

MODE="stdio"
BEARER_ENV=""
if [[ "$1" == "--url" ]]; then
  MODE="url"
  shift
  [[ $# -ge 2 ]] || usage
  NAME="$1"
  URL="$2"
  shift 2
  if [[ "${1:-}" == "--bearer-token-env" ]]; then
    BEARER_ENV="${2:-}"
    [[ -n "$BEARER_ENV" ]] || usage
  fi
else
  NAME="$1"
  shift
  COMMAND="$1"
  shift
  ARGS=("$@")
fi

mkdir -p "$(dirname "$MCP_FILE")"
touch "$MCP_FILE"

if grep -qE "^[[:space:]]*\[mcp_servers\.${NAME}\]" "$MCP_FILE"; then
  echo "错误: MCP 服务器已存在: ${NAME}" >&2
  exit 1
fi

{
  echo ""
  echo "[mcp_servers.${NAME}]"
  if [[ "$MODE" == "url" ]]; then
    echo "url = \"${URL}\""
    if [[ -n "$BEARER_ENV" ]]; then
      echo "bearer_token_env_var = \"${BEARER_ENV}\""
    fi
  else
    echo "command = \"${COMMAND}\""
    if [[ ${#ARGS[@]} -gt 0 ]]; then
      printf 'args = ['
      first=1
      for a in "${ARGS[@]}"; do
        if [[ $first -eq 1 ]]; then
          first=0
        else
          printf ', '
        fi
        # Escape backslash and double-quote for TOML string
        esc="${a//\\/\\\\}"
        esc="${esc//\"/\\\"}"
        printf '"%s"' "$esc"
      done
      echo ']'
    fi
  fi
} >> "$MCP_FILE"

echo "已添加 MCP 配置: ${NAME}"
echo "  文件: ${MCP_FILE}"
echo ""
echo "使配置生效:"
echo "  ${REPO}/bootstrap.sh"
echo ""
echo "提交到 Git:"
echo "  cd ${REPO} && git add mcp/user-servers.toml && git commit -m \"add mcp: ${NAME}\""
