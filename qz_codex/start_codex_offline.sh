#!/usr/bin/env bash
# 断网区启用：加载 API 环境（不直接启动 Codex）
# 必须在当前 shell：source 本脚本  （不要用 bash 子进程）
# 被 source 时勿 set -euo / exit，否则会关闭当前交互 shell（闪退）。

_cc_sourced=0
[[ "${BASH_SOURCE[0]}" != "$0" ]] && _cc_sourced=1
if ((_cc_sourced)); then
  :
else
  set -euo pipefail
fi

_cc_fail() {
  if ((_cc_sourced)); then
    return 1
  fi
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${CODEX_ENV_FILE:-$ROOT_DIR/script/codex/qz_codex/codex.api.env}"
# 只有显式传入非选项参数时才把它当配置文件；避免 source 时误读 Codex 的 -p/--help。
if [[ -n "${1:-}" && "${1:-}" != -* ]]; then
  ENV_FILE="$1"
fi
APP_WRAPPER="$ROOT_DIR/apps/codex/bin/codex"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "未找到配置文件: $ENV_FILE"
  echo "先执行：cp script/codex/codex.api.env.example script/codex/codex.api.env"
  _cc_fail
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -n "${BASE_URL:-}" ]]; then
  BASE_URL="${BASE_URL#"${BASE_URL%%[![:space:]]*}"}"
  BASE_URL="${BASE_URL%"${BASE_URL##*[![:space:]]}"}"
fi
if [[ -n "${API_KEY:-}" ]]; then
  API_KEY="${API_KEY#"${API_KEY%%[![:space:]]*}"}"
  API_KEY="${API_KEY%"${API_KEY##*[![:space:]]}"}"
fi

[[ -n "${BASE_URL:-}" ]] && export OPENAI_BASE_URL="$BASE_URL"
[[ -n "${API_KEY:-}" ]] && export OPENAI_API_KEY="$API_KEY"
[[ -n "${MODEL:-}" ]] && export OPENAI_MODEL="$MODEL"

if [[ -z "${OPENAI_BASE_URL:-}" ]]; then
  echo "BASE_URL 未配置（会映射到 OPENAI_BASE_URL）"
  _cc_fail
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "API_KEY 未配置（会映射到 OPENAI_API_KEY）"
  _cc_fail
fi

if [[ -x "$APP_WRAPPER" ]]; then
  ln -sfn "$APP_WRAPPER" /usr/local/bin/codex 2>/dev/null || true
  ln -sfn "$APP_WRAPPER" /usr/bin/codex 2>/dev/null || true
  hash -r 2>/dev/null || true
fi

if ! command -v codex >/dev/null 2>&1 && [[ ! -x "$APP_WRAPPER" ]]; then
  echo "未找到 codex 入口。请先执行：bash script/codex/install_codex_offline.sh"
  _cc_fail
fi

echo "[OK] Codex API 环境已就绪，可在任意目录运行 codex"
if [[ -x "$APP_WRAPPER" ]]; then
  echo "或执行: $APP_WRAPPER"
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[!] 检测到子 shell 执行：OPENAI_* 未写入当前终端。请改在同一终端执行："
  echo "    source \"$ROOT_DIR/script/codex/start_codex_offline.sh\""
fi
