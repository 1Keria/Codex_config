#!/usr/bin/env bash
# 一键启动 Codex：自动安装（幂等）、加载 API 配置并执行参数
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CODEX_DIR="$ROOT_DIR/script/codex/qz_codex"
if [[ ! -x "$ROOT_DIR/apps/codex/bin/codex" || ! -f "$ROOT_DIR/apps/codex/home/config.toml" ]]; then
  bash "$CODEX_DIR/setup_offline_codex.sh"
fi
# 兼容旧版 Codex 的 `-p "提示词"` 写法：0.155.1 中 -p 已改为 profile。
# 新版提示词应作为位置参数传入。
if [[ "${1:-}" == "-p" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    echo "-p 需要提供提示词" >&2
    exit 2
  fi
  exec "$ROOT_DIR/apps/codex/bin/codex" "$@"
fi
exec "$ROOT_DIR/apps/codex/bin/codex" "$@"
