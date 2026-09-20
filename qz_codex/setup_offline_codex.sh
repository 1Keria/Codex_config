#!/usr/bin/env bash
# 不可上网区一键安装并配置 Codex（共享目录，无需下载）
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CODEX_DIR="$ROOT_DIR/script/codex/qz_codex"
# 配置文件只通过 CODEX_ENV_FILE 指定；普通位置参数必须留给 Codex 提示词。
ENV_FILE="${CODEX_ENV_FILE:-$CODEX_DIR/codex.api.env}"
PROXY_ENV="$ROOT_DIR/offline_repo/codex/proxy.env"
if [[ -z "${CODEX_PROXY_BASE_URL:-}" && -f "$PROXY_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$PROXY_ENV"
fi

[[ -f "$ENV_FILE" ]] || { echo "缺少 API 配置: $ENV_FILE" >&2; exit 1; }
chmod 600 "$ENV_FILE" 2>/dev/null || true

# 允许命令行覆盖端点/模型，但不把密钥写入文件
if [[ -n "${CODEX_PROXY_BASE_URL:-}" ]]; then
  tmp="$(mktemp)"
  awk -v url="$CODEX_PROXY_BASE_URL" 'BEGIN{done=0} /^BASE_URL=/{print "BASE_URL=" url; done=1; next} {print} END{if(!done) print "BASE_URL=" url}' "$ENV_FILE" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$ENV_FILE"
fi
if [[ -n "${CODEX_MODEL:-}" ]]; then
  tmp="$(mktemp)"
  awk -v model="$CODEX_MODEL" 'BEGIN{done=0} /^MODEL=/{print "MODEL=" model; done=1; next} {print} END{if(!done) print "MODEL=" model}' "$ENV_FILE" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$ENV_FILE"
fi

# 仅校验必要字段，不输出密钥
set -a
source "$ENV_FILE"
set +a
[[ -n "${BASE_URL:-}" && -n "${API_KEY:-}" ]] || { echo "API 配置不完整: $ENV_FILE" >&2; exit 1; }

# 安装前验证当前环境能通过映射访问云豆，避免把仅联网区可达的内网地址写入配置。
python3 - "$BASE_URL" <<'PY'
import json, os, sys, urllib.request
base, key = sys.argv[1].rstrip('/'), os.environ['API_KEY']
req = urllib.request.Request(
    base + '/models',
    headers={'Authorization': 'Bearer ' + key, 'Accept': 'application/json'},
)
try:
    with urllib.request.urlopen(req, timeout=20) as response:
        payload = json.load(response)
    if response.status != 200 or not isinstance(payload.get('data'), list):
        raise RuntimeError('模型列表响应异常')
except Exception as exc:
    print(f'Codex API 映射不可用: {base}: {exc}', file=sys.stderr)
    raise SystemExit(1)
PY

# 环境文件更新和连通性验证后再安装，确保 config.toml 使用当前有效映射地址。
bash "$CODEX_DIR/install_codex_offline.sh" >/dev/null

# 合并仓库根目录的 AGENTS、MCP、skills、plugins；不会覆盖 yundou Provider。
if [[ -x "$CODEX_DIR/sync_personal_config.sh" ]]; then
  bash "$CODEX_DIR/sync_personal_config.sh"
fi
