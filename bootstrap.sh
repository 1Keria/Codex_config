#!/usr/bin/env bash
# Codex 统一入口：qz 离线部署 + 云豆 Provider + 个人 AGENTS/MCP/skills/plugins。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$REPO/../.." && pwd)"
QZ_DIR="$REPO/qz_codex"
DIRECT_DIR="$REPO/direct_codex"
CODEX_HOME="${CODEX_HOME:-$ROOT_DIR/apps/codex/home}"
export CODEX_HOME

usage() {
  cat <<'EOF'
用法：
  bash script/codex/bootstrap.sh qz          # qz 映射模式安装/恢复
  bash script/codex/bootstrap.sh direct      # 非 qz 环境直连云豆
  bash script/codex/bootstrap.sh sync        # 只同步 AGENTS/MCP/skills/plugins
  bash script/codex/bootstrap.sh check       # 版本、持久目录、模型调用自检
  bash script/codex/bootstrap.sh internet    # 可上网区准备离线包并启动 16067 代理

说明：
  - qz / direct 两种 API 模式由 qz_codex 分开管理。
  - sync 是两种模式共用的个人配置入口。
  - settings.json 仅保留兼容说明，不再生成 Provider 配置。
  - 所有运行状态保存在项目共享目录 apps/codex/home/。
EOF
}

cmd="${1:-help}"
case "$cmd" in
  qz|install|restore)
    bash "$QZ_DIR/setup_offline_codex.sh"
    ;;
  direct)
    bash "$DIRECT_DIR/setup_direct_codex.sh"
    ;;
  sync)
    synced=0
    if [[ -x "$ROOT_DIR/apps/codex/bin/codex" && -d "$ROOT_DIR/apps/codex/home" ]]; then
      CODEX_HOME="$ROOT_DIR/apps/codex/home" CODEX_BIN="$ROOT_DIR/apps/codex/bin/codex"         bash "$REPO/scripts/sync-personal-config.sh"
      synced=1
    fi
    direct_runtime="${CODEX_DIRECT_RUNTIME:-$REPO/.runtime/direct}"
    if [[ -x "$direct_runtime/bin/codex" && -d "$direct_runtime/home" ]]; then
      CODEX_HOME="$direct_runtime/home" CODEX_BIN="$direct_runtime/bin/codex"         bash "$REPO/scripts/sync-personal-config.sh"
      synced=1
    fi
    [[ "$synced" -eq 1 ]] || {
      echo "尚未安装 qz 或 direct 模式" >&2
      exit 1
    }
    ;;
  check)
    mode="$(cat "$REPO/.active-mode" 2>/dev/null || echo unknown)"
    case "$mode" in
      qz)
        CODEX_HOME="$ROOT_DIR/apps/codex/home" CODEX_BIN="$ROOT_DIR/apps/codex/bin/codex"           bash "$QZ_DIR/check_codex.sh"
        ;;
      direct)
        direct_runtime="${CODEX_DIRECT_RUNTIME:-$REPO/.runtime/direct}"
        CODEX_HOME="$direct_runtime/home" CODEX_BIN="$direct_runtime/bin/codex"           bash "$QZ_DIR/check_codex.sh"
        ;;
      *)
        echo "没有已激活模式，请先运行 bootstrap.sh qz 或 bootstrap.sh direct" >&2
        exit 1
        ;;
    esac
    ;;
  internet)
    bash "$QZ_DIR/setup_internet_codex.sh"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
