#!/usr/bin/env bash
# 一键启动 Codex：自动安装（幂等）、加载 API 配置并执行参数
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CODEX_DIR="$ROOT_DIR/script/codex/qz_codex"
bash "$CODEX_DIR/setup_offline_codex.sh"
source "$CODEX_DIR/start_codex_offline.sh"
exec "$ROOT_DIR/apps/codex/bin/codex" "$@"
