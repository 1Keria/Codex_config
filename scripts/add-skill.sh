#!/usr/bin/env bash
# 将第三方 skill 添加到 codex-setup 并链接到 ~/.agents/skills/
#
# 用法:
#   add-skill.sh <skill-name> <source-path>
#
# 示例:
#   add-skill.sh my-skill ~/Downloads/some-skill-dir
#   add-skill.sh my-skill ~/Downloads/SKILL.md

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${REPO}/skills"
ROOT_DIR="$(cd "$REPO/../.." && pwd)"
CODEX_SKILLS="$ROOT_DIR/apps/codex/home/skills"
AGENTS_SKILLS="${HOME}/.agents/skills"

usage() {
  echo "用法: $0 <skill-name> <source-path>"
  echo ""
  echo "  skill-name    skill 目录名（如 my-skill）"
  echo "  source-path   来源目录（含 SKILL.md）或单个 SKILL.md 文件"
  exit 1
}

[[ $# -eq 2 ]] || usage

NAME="$1"
SOURCE="$2"
DEST="${SKILLS_DIR}/${NAME}"

if [[ -e "$DEST" ]]; then
  echo "错误: ${DEST} 已存在" >&2
  exit 1
fi

mkdir -p "$SKILLS_DIR" "$CODEX_SKILLS" "$AGENTS_SKILLS"

if [[ -f "$SOURCE" ]]; then
  mkdir -p "$DEST"
  cp "$SOURCE" "${DEST}/SKILL.md"
elif [[ -d "$SOURCE" ]]; then
  cp -r "$SOURCE" "$DEST"
else
  echo "错误: 来源不存在: ${SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${DEST}/SKILL.md" ]]; then
  echo "错误: 复制后未找到 ${DEST}/SKILL.md" >&2
  rm -rf "$DEST"
  exit 1
fi

ln -sfn "$DEST" "${CODEX_SKILLS}/${NAME}"
ln -sfn "$DEST" "${AGENTS_SKILLS}/${NAME}"

echo "已添加 skill: ${NAME}"
echo "  仓库路径: ${DEST}"
echo "  持久链接: ${CODEX_SKILLS}/${NAME}"
echo "  兼容链接: ${AGENTS_SKILLS}/${NAME}"
echo ""
echo "下一步:"
echo "  cd ${REPO} && git add skills/${NAME} && git commit -m \"add skill: ${NAME}\""
