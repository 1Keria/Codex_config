#!/usr/bin/env bash
# 在任意资源区检查持久文件、映射、版本和最小模型请求。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CODEX_BIN="${CODEX_BIN:-$ROOT_DIR/.bin/codex}"
CODEX_HOME_DIR="${CODEX_HOME:-$ROOT_DIR/apps/codex/home}"
ENV_FILE="$ROOT_DIR/script/codex/qz_codex/codex.api.env"

[[ -x "$CODEX_BIN" ]] || { echo "缺少 Codex: $CODEX_BIN" >&2; exit 1; }
[[ -f "$CODEX_HOME_DIR/config.toml" ]] || { echo "缺少持久配置: $CODEX_HOME_DIR/config.toml" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "缺少 API 配置: $ENV_FILE" >&2; exit 1; }

version="$($CODEX_BIN --version)"
mode="$(cat "$CODEX_HOME_DIR/.deployment-mode" 2>/dev/null || echo unknown)"
result="$($CODEX_BIN exec --skip-git-repo-check --json '只回复 OK' 2>/dev/null)"
grep -q '"text":"OK"' <<<"$result" || { echo "模型测试未返回 OK" >&2; exit 1; }
grep -q '"type":"turn.completed"' <<<"$result" || { echo "模型测试未完成" >&2; exit 1; }
printf '[OK] %s；模式=%s；持久目录=%s；模型调用正常\n' "$version" "$mode" "$CODEX_HOME_DIR"
