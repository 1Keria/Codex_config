#!/usr/bin/env bash
# 可上网区一键准备离线包并后台启动云豆 API 代理
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CODEX_DIR="$ROOT_DIR/script/codex/qz_codex"
LOG_DIR="$ROOT_DIR/log"
LOG_FILE="$LOG_DIR/codex_yundou_proxy.log"
PROXY_ENV="$ROOT_DIR/offline_repo/codex/proxy.env"
PORT="${CODEX_PROXY_PORT:-16067}"
TARGET="${CODEX_TARGET_URL:-https://yundou.ai/v1}"
mkdir -p "$LOG_DIR"
bash "$CODEX_DIR/prepare_codex_offline.sh" >/dev/null

# 共享目录中写入代理地址；不可上网区会自动读取，无需手工输入。
# 可用 CODEX_PROXY_HOST 覆盖自动探测到的本机地址。
if [[ -z "${CODEX_PROXY_HOST:-}" ]]; then
  CODEX_PROXY_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
[[ -n "$CODEX_PROXY_HOST" ]] || { echo "无法自动获取代理主机地址" >&2; exit 1; }
mkdir -p "$(dirname "$PROXY_ENV")"
if [[ -n "${CODEX_PROXY_BASE_URL:-}" ]]; then
  printf 'CODEX_PROXY_BASE_URL=%s\n' "${CODEX_PROXY_BASE_URL%/}" > "$PROXY_ENV"
elif [[ ! -f "$PROXY_ENV" ]]; then
  printf 'CODEX_PROXY_BASE_URL=http://%s:%s\n' "$CODEX_PROXY_HOST" "$PORT" > "$PROXY_ENV"
fi
chmod 600 "$PROXY_ENV" 2>/dev/null || true
PYTHON_PACKAGES="$ROOT_DIR/apps/claude/python-packages"
if ! PYTHONPATH="$PYTHON_PACKAGES${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'import flask, requests, urllib3' >/dev/null 2>&1; then
  mkdir -p "$PYTHON_PACKAGES"
  python3 -m pip install --no-index \
    --find-links "$ROOT_DIR/offline_repo/claude/pip" \
    --target "$PYTHON_PACKAGES" \
    -r "$ROOT_DIR/apps/claude/requirements-proxy.txt" >/dev/null
fi
check() { python3 - "$PORT" "$TARGET" <<'PY' >/dev/null 2>&1
import json, sys, urllib.request
port, target = sys.argv[1:]
try:
    with urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=2) as r:
        d=json.loads(r.read())
    raise SystemExit(0 if d.get('target') == target else 1)
except Exception:
    raise SystemExit(1)
PY
}
if check; then exit 0; fi
nohup env TARGET_URL="$TARGET" PROXY_HOST=0.0.0.0 PROXY_PORT="$PORT" \
  bash "$ROOT_DIR/script/claude/start_api_proxy.sh" >>"$LOG_FILE" 2>&1 </dev/null &
for _ in $(seq 1 30); do
  check && exit 0
  sleep 1
done
echo "Codex 代理启动失败，请查看 $LOG_FILE" >&2
exit 1
