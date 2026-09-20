#!/usr/bin/env bash
# 联网区执行：准备固定版本 Codex CLI 离线资源；已有完整包时幂等跳过。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT_DIR/offline_repo/codex"
NPM_DIR="$OUT_DIR/npm"
MANIFEST_DIR="$OUT_DIR/manifests"
CODEX_VERSION="${CODEX_VERSION:-0.155.1}"
MAIN_TGZ="$NPM_DIR/openai-codex-${CODEX_VERSION}.tgz"
LINUX_TGZ="$NPM_DIR/openai-codex-linux-x64-${CODEX_VERSION}.tgz"

mkdir -p "$NPM_DIR" "$MANIFEST_DIR"

if [[ ! -s "$MAIN_TGZ" || ! -s "$LINUX_TGZ" ]]; then
  echo ">>> 下载 Codex ${CODEX_VERSION} 离线包"
  python3 - "$CODEX_VERSION" "$MAIN_TGZ" "$LINUX_TGZ" <<'PY'
import json, shutil, sys, urllib.request
version, main_path, linux_path = sys.argv[1:]
with urllib.request.urlopen('https://registry.npmjs.org/@openai/codex', timeout=30) as response:
    metadata = json.load(response)
items = [
    (version, main_path),
    (version + '-linux-x64', linux_path),
]
for package_version, destination in items:
    try:
        url = metadata['versions'][package_version]['dist']['tarball']
    except KeyError as exc:
        raise SystemExit(f'npm Registry 中未找到 @openai/codex@{package_version}') from exc
    with urllib.request.urlopen(url, timeout=300) as source, open(destination, 'wb') as output:
        shutil.copyfileobj(source, output)
PY
else
  echo ">>> 已存在 Codex ${CODEX_VERSION} 离线包，跳过下载"
fi

# 清理旧式本地包，避免安装时版本含义不清。
rm -f "$NPM_DIR/openai-codex-local.tgz" "$NPM_DIR/openai-codex-linux-x64-local.tgz"
printf '%s\n' "$CODEX_VERSION" > "$MANIFEST_DIR/codex.version.txt"
printf '%s\n' "$CODEX_VERSION" > "$MANIFEST_DIR/codex-linux-x64.version.txt"

echo "完成：$OUT_DIR"
