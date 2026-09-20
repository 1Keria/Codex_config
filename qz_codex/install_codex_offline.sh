#!/usr/bin/env bash
# 断网区执行：离线包安装到 apps/codex（offline_repo 仅存包）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
OFFLINE_DIR="${1:-$ROOT_DIR/offline_repo/codex}"
NPM_DIR="$OFFLINE_DIR/npm"
APP_DIR="$ROOT_DIR/apps/codex"
APP_BIN_DIR="$APP_DIR/bin"
APP_LOCAL_DIR="$APP_DIR/offline/codex"
SHARED_NODE_DIR="$ROOT_DIR/apps/node/bin"
APP_WRAPPER="$APP_BIN_DIR/codex"

mkdir -p "$APP_BIN_DIR" "$SHARED_NODE_DIR"

# 优先按 manifest 指定版本安装，避免多个 tgz 共存时误选其他版本。
DESIRED_VERSION=""
if [[ -f "$OFFLINE_DIR/manifests/codex.version.txt" ]]; then
  DESIRED_VERSION="$(tr -d '[:space:]' < "$OFFLINE_DIR/manifests/codex.version.txt")"
fi
CODEX_TGZ=""
if [[ -n "$DESIRED_VERSION" && -f "$NPM_DIR/openai-codex-${DESIRED_VERSION}.tgz" ]]; then
  CODEX_TGZ="$NPM_DIR/openai-codex-${DESIRED_VERSION}.tgz"
else
  CODEX_TGZ="$(find "$NPM_DIR" -maxdepth 1 -type f -name 'openai-codex-[0-9]*.tgz' ! -name '*linux-x64*' | sort -V | tail -n 1 || true)"
fi
if [[ -n "$CODEX_TGZ" ]]; then
  if [[ -z "$CODEX_TGZ" ]]; then
    echo "未找到离线包：$NPM_DIR/openai-codex*.tgz"
    echo "请先执行：bash script/codex/prepare_codex_offline.sh"
    exit 1
  fi

  echo ">>> 解包安装 Codex 到 apps/codex"
  rm -rf "$APP_LOCAL_DIR"
  mkdir -p "$APP_LOCAL_DIR"
  tar -xzf "$CODEX_TGZ" -C "$APP_LOCAL_DIR"
  if [[ ! -f "$APP_LOCAL_DIR/package/bin/codex.js" ]]; then
    echo "离线包结构异常：未找到 package/bin/codex.js"
    exit 1
  fi
else
  echo ">>> 未找到 Codex 主包"
  exit 1
fi

# 新版原生包的目录是 vendor/<triple>/bin/codex；旧版是 vendor/<triple>/codex/codex。
# 创建兼容链接，让不同版本的 JS 启动器都能找到原生二进制。
for _vdir in "$APP_DIR/node_modules/@openai/codex-linux-x64/vendor" "$APP_DIR/node_modules/@openai/codex-linux-arm64/vendor"; do
  for _triple in x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
    if [[ -x "$_vdir/$_triple/bin/codex" && ! -e "$_vdir/$_triple/codex/codex" ]]; then
      mkdir -p "$_vdir/$_triple/codex"
      ln -s ../bin/codex "$_vdir/$_triple/codex/codex"
    fi
  done
done

# 可选依赖：原生 codex 二进制（npm pack @openai/codex-linux-x64 会得到此包）
LINUX_TGZ=""
if [[ -n "$DESIRED_VERSION" && -f "$NPM_DIR/openai-codex-linux-x64-${DESIRED_VERSION}.tgz" ]]; then
  LINUX_TGZ="$NPM_DIR/openai-codex-linux-x64-${DESIRED_VERSION}.tgz"
else
  LINUX_TGZ="$(find "$NPM_DIR" -maxdepth 1 -type f -name 'openai-codex-linux-x64-[0-9]*.tgz' | sort -V | tail -n 1 || true)"
fi
if [[ -n "$LINUX_TGZ" ]]; then
  echo ">>> 安装 Codex Linux 原生包"
  mkdir -p "$APP_DIR/node_modules/@openai"
  TMPD="$APP_DIR/node_modules/@openai/.codex-linux-extract"
  rm -rf "$TMPD" "$APP_DIR/node_modules/@openai/codex-linux-x64"
  mkdir -p "$TMPD"
  tar -xzf "$LINUX_TGZ" -C "$TMPD"
  if [[ ! -d "$TMPD/package" ]]; then
    echo "警告：$LINUX_TGZ 内未找到 package/，跳过原生包"
    rm -rf "$TMPD"
  else
    mv "$TMPD/package" "$APP_DIR/node_modules/@openai/codex-linux-x64"
    rm -rf "$TMPD"
  fi
elif [[ ! -x "$APP_DIR/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/codex/codex" && ! -x "$APP_DIR/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex" ]] 2>/dev/null; then
  echo ">>> 警告：未找到 openai-codex-linux-x64*.tgz，且 node_modules 中无可用原生 codex。"
  echo "    请在可联网环境执行：bash script/codex/prepare_codex_offline.sh（需 npm，会下载平台包）"
fi


# 原生包解压后再创建旧版 JS 启动器需要的兼容链接。
for _vdir in "$APP_DIR/node_modules/@openai/codex-linux-x64/vendor" "$APP_DIR/node_modules/@openai/codex-linux-arm64/vendor"; do
  for _triple in x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
    if [[ -x "$_vdir/$_triple/bin/codex" && ! -e "$_vdir/$_triple/codex/codex" ]]; then
      mkdir -p "$_vdir/$_triple/codex"
      ln -s ../bin/codex "$_vdir/$_triple/codex/codex"
    fi
  done
done

cat > "$APP_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH="\$(readlink -f "\${BASH_SOURCE[0]}")"
APP_DIR="\$(cd "\$(dirname "\$SCRIPT_PATH")/.." && pwd)"
ROOT_DIR="\$(cd "\$APP_DIR/../.." && pwd)"
CLI_JS="\$APP_DIR/offline/codex/package/bin/codex.js"
RUNTIME_NODE="\$APP_DIR/../node/bin/node"
ENV_FILE="\$ROOT_DIR/script/codex/qz_codex/codex.api.env"
export CODEX_HOME="\$APP_DIR/home"
mkdir -p "\$CODEX_HOME"
if [[ -f "\$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "\$ENV_FILE"
  set +a
fi
[[ -n "\${API_KEY:-}" ]] && export OPENAI_API_KEY="\$API_KEY"
if [[ ! -f "\$CLI_JS" ]]; then
  echo "未找到 \$CLI_JS"
  exit 1
fi
if [[ -x "\$RUNTIME_NODE" ]]; then
  exec "\$RUNTIME_NODE" "\$CLI_JS" "\$@"
elif command -v node >/dev/null 2>&1; then
  exec node "\$CLI_JS" "\$@"
elif command -v nodejs >/dev/null 2>&1; then
  exec nodejs "\$CLI_JS" "\$@"
elif compgen -G "/root/.cursor-server/bin/linux-x64/*/node" >/dev/null 2>&1; then
  NODE_BIN="\$(ls /root/.cursor-server/bin/linux-x64/*/node | head -n 1)"
  exec "\$NODE_BIN" "\$CLI_JS" "\$@"
else
  echo "未检测到 node，请先安装 node（或确保 PATH 包含 node）"
  exit 1
fi
EOF
chmod +x "$APP_WRAPPER"

NODE_BIN=""
if command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
elif command -v nodejs >/dev/null 2>&1; then
  NODE_BIN="$(command -v nodejs)"
elif compgen -G "/root/.cursor-server/bin/linux-x64/*/node" >/dev/null 2>&1; then
  NODE_BIN="$(ls /root/.cursor-server/bin/linux-x64/*/node | head -n 1)"
fi
if [[ -n "$NODE_BIN" ]]; then
  if [[ "$(readlink -f "$NODE_BIN")" != "$(readlink -f "$SHARED_NODE_DIR/node" 2>/dev/null || true)" ]]; then
    cp -f "$NODE_BIN" "$SHARED_NODE_DIR/node"
  fi
  chmod +x "$SHARED_NODE_DIR/node" 2>/dev/null || true
fi

# 原生 codex / ripgrep 在部分共享盘上会失去 +x。
for _plat in codex-linux-x64 codex-linux-arm64; do
  _vdir="$APP_DIR/node_modules/@openai/$_plat/vendor"
  if [[ -d "$_vdir" ]]; then
    find "$_vdir" -type f \( -name codex -o -name rg \) -exec chmod +x {} + 2>/dev/null || true
  fi
done

# 将旧个人目录中的配置、状态和会话迁入共享项目目录（只执行一次）。
CODEX_HOME_DIR="$APP_DIR/home"
LEGACY_CODEX_HOME="${HOME}/.codex"
MIGRATION_MARKER="$CODEX_HOME_DIR/.qz_persistent_home"
mkdir -p "$CODEX_HOME_DIR"
if [[ ! -f "$MIGRATION_MARKER" && -d "$LEGACY_CODEX_HOME" && ! -L "$LEGACY_CODEX_HOME" ]]; then
  cp -a "$LEGACY_CODEX_HOME/." "$CODEX_HOME_DIR/"
fi
touch "$MIGRATION_MARKER"
chmod 700 "$CODEX_HOME_DIR" 2>/dev/null || true
# 兼容不经过项目包装器启动的工具；该软链接丢失时可由安装脚本重建。
if [[ ! -e "$LEGACY_CODEX_HOME" ]]; then
  ln -s "$CODEX_HOME_DIR" "$LEGACY_CODEX_HOME" 2>/dev/null || true
fi

# 生成云豆自定义 Provider 配置：保留完整 Harness，强制 HTTP/SSE，禁用 WebSocket。
CODEX_ENV_FILE="$ROOT_DIR/script/codex/qz_codex/codex.api.env"
if [[ -f "$CODEX_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CODEX_ENV_FILE"
  set +a
  cat > "$CODEX_HOME_DIR/config.toml" <<EOF
# Generated by qz_codex/install_codex_offline.sh
model = "${MODEL:-gpt-5.6}"
model_provider = "yundou"
model_reasoning_effort = "low"

[model_providers.yundou]
name = "Yundou"
base_url = "${BASE_URL}"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
supports_websockets = false
request_max_retries = 3
stream_max_retries = 3
EOF
  chmod 600 "$CODEX_HOME_DIR/config.toml"
fi

# 持久入口位于共享项目；系统入口只是可随时重建的软链接。
mkdir -p "$ROOT_DIR/.bin"
ln -sfn "$APP_WRAPPER" "$ROOT_DIR/.bin/codex"
GLOBAL_WRAPPER="$ROOT_DIR/.bin/codex"
if ln -sfn "$APP_WRAPPER" /usr/local/bin/codex 2>/dev/null; then
  GLOBAL_WRAPPER="/usr/local/bin/codex"
fi
ln -sfn "$APP_WRAPPER" /usr/bin/codex 2>/dev/null || true
ln -sfn "$SHARED_NODE_DIR/node" /usr/local/bin/node 2>/dev/null || true
ln -sfn "$SHARED_NODE_DIR/node" /usr/local/bin/nodejs 2>/dev/null || true
hash -r 2>/dev/null || true

echo ">>> 已安装：$APP_WRAPPER"
echo ">>> 持久化 CODEX_HOME：$CODEX_HOME_DIR"
echo ">>> 全局入口：$GLOBAL_WRAPPER"
