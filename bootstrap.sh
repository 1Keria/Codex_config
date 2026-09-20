#!/usr/bin/env bash
# Codex 统一入口：qz 离线部署 + 云豆 Provider + 个人 AGENTS/MCP/skills/plugins。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$REPO/../.." && pwd)"
QZ_DIR="$REPO/qz_codex"
CODEX_HOME="${CODEX_HOME:-$ROOT_DIR/apps/codex/home}"
export CODEX_HOME

usage() {
  cat <<'EOF'
用法：
  bash script/codex/bootstrap.sh              # 完整安装/恢复（默认）
  bash script/codex/bootstrap.sh install      # 同上
  bash script/codex/bootstrap.sh sync         # 只同步 AGENTS/MCP/skills/plugins
  bash script/codex/bootstrap.sh check        # 版本、持久目录、模型调用自检
  bash script/codex/bootstrap.sh internet     # 可上网区准备离线包并启动 16067 代理

说明：
  - API、模型和 qz 映射由 qz_codex 管理。
  - settings.json 仅保留兼容说明，不再生成 Provider 配置。
  - 所有运行状态保存在项目共享目录 apps/codex/home/。
EOF
}

cmd="${1:-install}"
case "$cmd" in
  install|restore)
    bash "$QZ_DIR/setup_offline_codex.sh"
    ;;
  sync)
    [[ -x "$ROOT_DIR/apps/codex/bin/codex" ]] || {
      echo "Codex 尚未安装，请先执行: bash $REPO/bootstrap.sh install" >&2
      exit 1
    }
    bash "$QZ_DIR/sync_personal_config.sh"
    ;;
  check)
    bash "$QZ_DIR/check_codex.sh"
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
