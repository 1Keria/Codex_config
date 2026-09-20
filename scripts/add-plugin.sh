#!/usr/bin/env bash
# 安装 plugin 并记录到 plugins.lock
#
# 用法:
#   add-plugin.sh <plugin@marketplace>
#
# 示例:
#   add-plugin.sh github@openai-curated

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO}/plugins.lock"

[[ $# -eq 1 ]] || { echo "用法: $0 <plugin@marketplace>"; exit 1; }

PLUGIN="$1"

if ! command -v codex >/dev/null 2>&1; then
  echo "错误: 未找到 codex 命令（请先运行 bash ${REPO}/bootstrap.sh qz 或 direct）" >&2
  exit 1
fi

if ! codex plugin --help >/dev/null 2>&1; then
  echo "错误: 当前 Codex 不支持 plugin 子命令，请升级到 >= 0.137" >&2
  echo "  请运行: bash ${REPO}/qz_codex/setup_internet_codex.sh" >&2
  exit 1
fi

echo "安装 plugin: ${PLUGIN}"
codex plugin add "$PLUGIN"

if grep -qxF "$PLUGIN" "$LOCK_FILE" 2>/dev/null; then
  echo "plugins.lock 中已存在: ${PLUGIN}"
else
  echo "$PLUGIN" >> "$LOCK_FILE"
  echo "已追加到 plugins.lock: ${PLUGIN}"
fi

echo ""
echo "下一步:"
echo "  cd ${REPO} && git add plugins.lock && git commit -m \"add plugin: ${PLUGIN}\""
