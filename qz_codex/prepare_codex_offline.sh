#!/usr/bin/env bash
# 联网区执行：准备 Codex CLI 离线资源
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT_DIR/offline_repo/codex"
NPM_DIR="$OUT_DIR/npm"
MANIFEST_DIR="$OUT_DIR/manifests"

mkdir -p "$NPM_DIR" "$MANIFEST_DIR"

if command -v npm >/dev/null 2>&1; then
  echo ">>> 下载 Codex npm 包"
  (
    cd "$NPM_DIR"
    npm pack @openai/codex
    npm pack @openai/codex-linux-x64 || true
  )
else
  echo ">>> 未检测到 npm，尝试用本地 node_modules 生成离线包"
  LOCAL_PKG_DIR="$ROOT_DIR/apps/codex/node_modules/@openai/codex"
  LOCAL_TGZ="$NPM_DIR/openai-codex-local.tgz"
  if [[ ! -d "$LOCAL_PKG_DIR" ]]; then
    echo "未找到本地 Codex 包目录：$LOCAL_PKG_DIR"
    echo "请在有 npm 的环境执行一次 prepare，或先准备 apps/codex/node_modules"
    exit 1
  fi
  python3 - <<PY
import os, tarfile
pkg_dir = os.path.abspath("$LOCAL_PKG_DIR")
out_tgz = os.path.abspath("$LOCAL_TGZ")
with tarfile.open(out_tgz, "w:gz") as tar:
    for root, _, files in os.walk(pkg_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, pkg_dir)
            tar.add(full, arcname=os.path.join("package", rel))
print(out_tgz)
PY
  echo ">>> 已生成离线包：$LOCAL_TGZ"
  LOCAL_LINUX_DIR="$ROOT_DIR/apps/codex/node_modules/@openai/codex-linux-x64"
  if [[ -d "$LOCAL_LINUX_DIR" ]]; then
    LOCAL_LINUX_TGZ="$NPM_DIR/openai-codex-linux-x64-local.tgz"
    python3 - <<PY
import os, tarfile
pkg_dir = os.path.abspath("$LOCAL_LINUX_DIR")
out_tgz = os.path.abspath("$LOCAL_LINUX_TGZ")
with tarfile.open(out_tgz, "w:gz") as tar:
    for root, _, files in os.walk(pkg_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, pkg_dir)
            tar.add(full, arcname=os.path.join("package", rel))
print(out_tgz)
PY
    echo ">>> 已生成 Linux 原生离线包：$LOCAL_LINUX_TGZ"
  else
    echo ">>> 未找到 $LOCAL_LINUX_DIR，断网机仅装主包会无法启动 codex；请在有 npm 时执行本脚本以拉取平台包"
  fi
fi

echo ">>> 记录版本"
if command -v npm >/dev/null 2>&1; then
  npm view @openai/codex version > "$MANIFEST_DIR/codex.version.txt"
  npm view @openai/codex-linux-x64 version > "$MANIFEST_DIR/codex-linux-x64.version.txt" || true
else
  echo "local-pack" > "$MANIFEST_DIR/codex.version.txt"
  echo "local-pack" > "$MANIFEST_DIR/codex-linux-x64.version.txt"
fi

echo "完成：$OUT_DIR"
