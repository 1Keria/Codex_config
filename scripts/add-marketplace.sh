#!/usr/bin/env bash
# 添加 marketplace 并记录到 marketplaces.lock
#
# 用法:
#   add-marketplace.sh <source> [--ref REF] [--sparse PATH]...
#
# 示例:
#   add-marketplace.sh owner/repo
#   add-marketplace.sh owner/repo --ref main
#   add-marketplace.sh https://github.com/owner/repo.git --sparse .agents/plugins

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO}/marketplaces.lock"

[[ $# -ge 1 ]] || {
  echo "用法: $0 <source> [--ref REF] [--sparse PATH]..."
  exit 1
}

if ! command -v codex >/dev/null 2>&1; then
  echo "错误: 未找到 codex 命令（请先运行 ${REPO}/bootstrap.sh）" >&2
  exit 1
fi

if ! codex plugin marketplace --help >/dev/null 2>&1; then
  echo "错误: 当前 Codex 不支持 plugin marketplace，请升级到 >= 0.137" >&2
  exit 1
fi

# 整行原样写入 lock，便于 bootstrap 复现
LOCK_LINE="$*"

echo "添加 marketplace: ${LOCK_LINE}"
# shellcheck disable=SC2068
codex plugin marketplace add $@

if grep -qxF "$LOCK_LINE" "$LOCK_FILE" 2>/dev/null; then
  echo "marketplaces.lock 中已存在: ${LOCK_LINE}"
else
  echo "$LOCK_LINE" >> "$LOCK_FILE"
  echo "已追加到 marketplaces.lock: ${LOCK_LINE}"
fi

echo ""
echo "下一步:"
echo "  cd ${REPO} && git add marketplaces.lock && git commit -m \"add marketplace\""
