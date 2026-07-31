#!/usr/bin/env bash
# 新机器一键恢复 Codex 个人配置
# 用法: ~/codex-setup/bootstrap.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AGENTS_SKILLS="${HOME}/.agents/skills"
REAL_CODEX_CANDIDATES=(
  "${HOME}/codex/node_modules/.bin/codex"
  "${HOME}/.npm-global/bin/codex"
  "${HOME}/.local/node/bin/codex"
  "${HOME}/codex/bin/codex"
)

read_lock_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -v '^\s*#' "$file" | grep -v '^\s*$' || true
}

codex_has_plugin_cli() {
  # 0.137+ 才有 `codex plugin`
  "${REAL_CODEX}" plugin --help >/dev/null 2>&1
}

log()  { echo "[codex-setup] $*"; }
warn() { echo "[codex-setup] WARNING: $*" >&2; }
die()  { echo "[codex-setup] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

is_setup_wrapper() {
  local path="$1"
  [[ -f "$path" ]] && grep -q 'codex-setup wrapper' "$path" 2>/dev/null
}

find_real_codex() {
  local candidate
  for candidate in "${REAL_CODEX_CANDIDATES[@]}"; do
    [[ -e "$candidate" ]] || continue
    is_setup_wrapper "$candidate" && continue
    if [[ -x "$candidate" ]] || [[ -L "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  if command -v codex >/dev/null 2>&1; then
    candidate="$(command -v codex)"
    if ! is_setup_wrapper "$candidate"; then
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}

install_wrapper() {
  local real_codex="$1"
  local wrapper="${HOME}/.local/bin/codex"
  mkdir -p "${HOME}/.local/bin"

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
# codex-setup wrapper — loads API key then exec real Codex
set -euo pipefail
REPO="${REPO}"
REAL_CODEX="${real_codex}"

load_env() {
  local f="\$1"
  [[ -f "\$f" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "\$f"
  set +a
}

load_env "\${REPO}/.env"
load_env "\${HOME}/claude-setup/.env"

if [[ -z "\${OPENAI_API_KEY:-}" && -n "\${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
  export OPENAI_API_KEY="\${ANTHROPIC_AUTH_TOKEN}"
fi

exec "\${REAL_CODEX}" "\$@"
EOF
  chmod +x "$wrapper"
  log "已安装 PATH 包装器: ${wrapper} -> ${real_codex}"
}

# --- 前置检查 ---

require_cmd jq
if ! command -v envsubst >/dev/null 2>&1; then
  warn "未找到 envsubst，MCP 配置中的 \${VAR} 将不会被展开（可安装 gettext 包）"
fi

REAL_CODEX="$(find_real_codex)" || die "未找到 Codex 可执行文件。请先安装: npm install --prefix ~/codex @openai/codex@latest"
log "Codex 二进制: ${REAL_CODEX}"
CODEX_VERSION="$("${REAL_CODEX}" --version 2>/dev/null | head -1 || true)"
log "Codex 版本: ${CODEX_VERSION:-unknown}"
"${REAL_CODEX}" --version >/dev/null 2>&1 || die "Codex 无法运行: ${REAL_CODEX}"

mkdir -p "${CODEX_HOME}" "${AGENTS_SKILLS}"

# 加载环境变量
if [[ -f "${REPO}/.env" ]]; then
  log "加载 ${REPO}/.env"
  set -a
  # shellcheck disable=SC1091
  source "${REPO}/.env"
  set +a
fi

if [[ -f "${HOME}/claude-setup/.env" ]]; then
  log "加载 ${HOME}/claude-setup/.env（可复用 API Key）"
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/claude-setup/.env"
  set +a
fi

if [[ -z "${OPENAI_API_KEY:-}" && -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
  export OPENAI_API_KEY="${ANTHROPIC_AUTH_TOKEN}"
  log "已将 ANTHROPIC_AUTH_TOKEN 映射为 OPENAI_API_KEY"
fi

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  warn "未设置 OPENAI_API_KEY。请: cp ${REPO}/.env.example ${REPO}/.env 并填入密钥"
fi

# --- 1. 安装 PATH 包装器 ---

install_wrapper "${REAL_CODEX}"
# 后续 marketplace/plugin 走包装器，保证密钥环境一致
export PATH="${HOME}/.local/bin:${PATH}"

# --- 2. 同步 config.toml（合并 MCP） ---

if [[ -f "${REPO}/config.toml" ]]; then
  log "同步 config.toml -> ${CODEX_HOME}/config.toml"
  tmp_config="$(mktemp)"
  cat "${REPO}/config.toml" > "$tmp_config"
  echo "" >> "$tmp_config"

  MCP_FILE="${REPO}/mcp/user-servers.toml"
  if [[ -f "$MCP_FILE" ]] && grep -qE '^\s*\[mcp_servers\.' "$MCP_FILE"; then
    log "合并 MCP 配置..."
    if command -v envsubst >/dev/null 2>&1; then
      # HOME 等常见变量可展开
      export HOME
      envsubst < "$MCP_FILE" >> "$tmp_config"
    else
      cat "$MCP_FILE" >> "$tmp_config"
    fi
  else
    log "MCP 配置为空，跳过（参考 mcp/user-servers.example.toml）"
  fi

  mv "$tmp_config" "${CODEX_HOME}/config.toml"
  log "  已写入 ${CODEX_HOME}/config.toml"
fi

# --- 3. 同步 AGENTS.md ---

if [[ -f "${REPO}/AGENTS.md" ]]; then
  log "同步 AGENTS.md -> ${CODEX_HOME}/AGENTS.md"
  cp "${REPO}/AGENTS.md" "${CODEX_HOME}/AGENTS.md"
fi

# --- 4. 链接独立 Skills -> ~/.agents/skills ---

log "链接独立 Skills..."
skill_count=0
for skill_dir in "${REPO}"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  [[ "$name" == "README.md" ]] && continue
  if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
    warn "  跳过 ${name}：缺少 SKILL.md"
    continue
  fi
  ln -sfn "$skill_dir" "${AGENTS_SKILLS}/${name}"
  log "  skill linked: ${name}"
  skill_count=$((skill_count + 1))
done
log "  共链接 ${skill_count} 个 skill"

# --- 5. Marketplace / Plugin（需 Codex >= 0.137） ---

if codex_has_plugin_cli; then
  log "添加 Marketplace..."
  while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    log "  marketplace add: $source"
    # shellcheck disable=SC2086
    if ! codex plugin marketplace add ${source} 2>/dev/null; then
      warn "  跳过或已存在: $source"
    fi
  done < <(read_lock_file "${REPO}/marketplaces.lock")

  log "安装 Plugin..."
  while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue
    log "  plugin add: $plugin"
    if ! codex plugin add "$plugin" 2>/dev/null; then
      warn "  安装失败或已安装: $plugin"
    fi
  done < <(read_lock_file "${REPO}/plugins.lock")
else
  warn "当前 Codex 无 plugin 子命令（需要 >= 0.137），跳过 marketplace/plugin 恢复"
  warn "升级: npm install --prefix ~/codex @openai/codex@latest && ${REPO}/bootstrap.sh"
fi

# --- 完成 ---

echo ""
log "恢复完成！"
echo ""
echo "  下一步："
echo "    1. 新开终端（或: source ~/.bashrc）确保 ~/.local/bin 在 PATH 前部"
echo "    2. 验证版本:   codex --version"
echo "    3. 验证插件:   codex plugin list"
echo "    4. 验证 MCP:   codex mcp list"
echo "    5. 启动 Codex:  codex"
echo ""
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  log "OPENAI_API_KEY 已就绪（长度 ${#OPENAI_API_KEY}）"
else
  warn "OPENAI_API_KEY 仍为空，Codex 可能无法调用模型"
fi

