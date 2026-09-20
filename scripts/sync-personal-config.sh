#!/usr/bin/env bash
# 将仓库根目录的 AGENTS/MCP/skills/plugins 合并到 qz 持久 Codex Home。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$REPO/../.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:?请通过 CODEX_HOME 指定要同步的运行时 Home}"
CODEX_BIN="${CODEX_BIN:?请通过 CODEX_BIN 指定对应的 Codex 入口}"
LEGACY_SKILLS_DIR="${HOME}/.agents/skills"

log() { echo "[codex-sync] $*"; }
warn() { echo "[codex-sync] WARNING: $*" >&2; }
read_lock_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true
}

mkdir -p "$CODEX_HOME_DIR" "$CODEX_HOME_DIR/skills" "$LEGACY_SKILLS_DIR"
export CODEX_HOME="$CODEX_HOME_DIR"

# 1. 个人全局指令
if [[ -f "$REPO/AGENTS.md" ]]; then
  cp "$REPO/AGENTS.md" "$CODEX_HOME_DIR/AGENTS.md"
  log "AGENTS.md -> $CODEX_HOME_DIR/AGENTS.md"
fi

# 2. Skills：真实内容留在 Git 仓库，持久 Home 与兼容目录只保存软链接。
skill_count=0
for skill_dir in "$REPO"/skills/*/; do
  [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
  name="$(basename "$skill_dir")"
  ln -sfn "$skill_dir" "$CODEX_HOME_DIR/skills/$name"
  ln -sfn "$skill_dir" "$LEGACY_SKILLS_DIR/$name"
  skill_count=$((skill_count + 1))
done
log "已同步 $skill_count 个 skill"

# 3. MCP：只替换 bootstrap 管理的区块，绝不覆盖 qz Provider 与模型配置。
MCP_FILE="$REPO/mcp/user-servers.json"
CONFIG_FILE="$CODEX_HOME_DIR/config.toml"
[[ -f "$CONFIG_FILE" ]] || { warn "缺少 $CONFIG_FILE，请先运行 setup_offline_codex.sh"; exit 1; }
python3 - "$MCP_FILE" "$CONFIG_FILE" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

mcp_path, config_path = map(Path, sys.argv[1:])
begin = "# >>> codex-config managed MCP >>>"
end = "# <<< codex-config managed MCP <<<"
config = config_path.read_text(encoding="utf-8")
config = re.sub(
    rf"\n?{re.escape(begin)}.*?{re.escape(end)}\n?",
    "\n",
    config,
    flags=re.S,
).rstrip() + "\n"

if mcp_path.is_file():
    payload = json.loads(mcp_path.read_text(encoding="utf-8"))
else:
    payload = {"mcpServers": {}}
servers = payload.get("mcpServers") or {}

def toml_string(value):
    return json.dumps(str(value), ensure_ascii=False)

def table_key(value):
    return json.dumps(str(value), ensure_ascii=False)

lines = [begin]
for name, raw in servers.items():
    cfg = raw or {}
    key = table_key(name)
    lines.extend(["", f"[mcp_servers.{key}]"])
    if cfg.get("url"):
        lines.append(f"url = {toml_string(cfg['url'])}")
        if cfg.get("bearer_token_env_var"):
            lines.append(
                f"bearer_token_env_var = {toml_string(cfg['bearer_token_env_var'])}"
            )
    else:
        if cfg.get("command"):
            lines.append(f"command = {toml_string(cfg['command'])}")
        if cfg.get("args"):
            args = ", ".join(toml_string(item) for item in cfg["args"])
            lines.append(f"args = [{args}]")
        if cfg.get("cwd"):
            lines.append(f"cwd = {toml_string(cfg['cwd'])}")
        static_env = {}
        forwarded_env = []
        for env_key, env_value in (cfg.get("env") or {}).items():
            match = re.fullmatch(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", str(env_value))
            if match:
                forwarded_env.append(match.group(1))
            else:
                static_env[env_key] = env_value
        explicit_env_vars = cfg.get("env_vars") or []
        forwarded_env.extend(str(item) for item in explicit_env_vars)
        if forwarded_env:
            rendered = ", ".join(toml_string(item) for item in dict.fromkeys(forwarded_env))
            lines.append(f"env_vars = [{rendered}]")
        if static_env:
            lines.extend(["", f"[mcp_servers.{key}.env]"])
            for env_key, env_value in static_env.items():
                lines.append(f"{env_key} = {toml_string(env_value)}")
lines.extend(["", end])
config_path.write_text(config + "\n".join(lines) + "\n", encoding="utf-8")
print(f"[codex-sync] 已合并 {len(servers)} 个 MCP server")
PY
chmod 600 "$CONFIG_FILE"

# 4. Marketplace / Plugin。锁文件为空时不会联网；失败只警告，不破坏主体配置。
if [[ -x "$CODEX_BIN" ]] && "$CODEX_BIN" plugin --help >/dev/null 2>&1; then
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    log "恢复 marketplace: $source"
    # shellcheck disable=SC2086
    "$CODEX_BIN" plugin marketplace add $source >/dev/null 2>&1 || warn "marketplace 跳过或恢复失败: $source"
  done < <(read_lock_file "$REPO/marketplaces.lock")

  while IFS= read -r plugin; do
    [[ -n "$plugin" ]] || continue
    log "恢复 plugin: $plugin"
    "$CODEX_BIN" plugin add "$plugin" >/dev/null 2>&1 || warn "plugin 跳过或恢复失败: $plugin"
  done < <(read_lock_file "$REPO/plugins.lock")
else
  warn "当前 Codex 无 plugin 子命令，跳过 plugin/marketplace"
fi

log "个人配置同步完成；Provider 保持 yundou + HTTP/SSE"
