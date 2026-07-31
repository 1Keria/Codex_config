# Codex 个人配置仓库

用 Git 管理 Codex CLI 的**个人全局配置**，形式对齐 `~/claude-setup`，方便迁移。

远程仓库：[github.com/1Keria/Codex_config](https://github.com/1Keria/Codex_config)

---

## 本仓库管理什么

| 类型 | 仓库中的位置 | 机器上的位置 |
|------|-------------|-------------|
| **第三方 API** | `settings.json`（端点/模型）+ `.env`（密钥） | 生成 `~/.codex/config.toml` + PATH 包装器注入密钥 |
| **Plugin** | `plugins.lock` + `marketplaces.lock` | `codex plugin` 自动管理 |
| **独立 Skill** | `skills/<名字>/` | `~/.agents/skills/<名字>/`（符号链接） |
| **独立 MCP** | `mcp/user-servers.json` | 合并进 `~/.codex/config.toml` |
| **个人偏好** | `AGENTS.md` | `~/.codex/AGENTS.md` |

---

## 目录结构

```
codex-setup/
├── bootstrap.sh
├── README.md
├── .env / .env.example
├── settings.json             # 和 claude-setup 一样：端点、模型
├── AGENTS.md
├── plugins.lock
├── marketplaces.lock
├── skills/
├── mcp/
│   ├── user-servers.json
│   └── user-servers.example.json
└── scripts/
    ├── add-plugin.sh
    ├── add-marketplace.sh
    ├── add-skill.sh
    └── add-mcp.sh
```

---

## 第三方 API（Auto-Code）

改 `settings.json`，密钥放 `.env`，然后 `bootstrap.sh`。

```json
{
  "permissions": {
    "allow": [],
    "deny": []
  },
  "env": {
    "OPENAI_BASE_URL": "https://vip.auto-code.net/v1",
    "OPENAI_MODEL": "gpt-5.5"
  }
}
```

| 配置项 | 存放位置 | 说明 |
|--------|----------|------|
| API 地址 | `settings.json` → `OPENAI_BASE_URL` | 当前：`https://vip.auto-code.net/v1` |
| 默认模型 | `settings.json` → `OPENAI_MODEL` | 当前：`gpt-5.5` |
| API Key | `.env` → `OPENAI_API_KEY` | 也可复用 `claude-setup` 的 `ANTHROPIC_AUTH_TOKEN` |

切换模型：改 `OPENAI_MODEL`，再运行 `~/codex-setup/bootstrap.sh`。

### 首次配置

```bash
cd ~/codex-setup
cp .env.example .env   # 若已用 claude-setup 的 Key，可跳过
~/codex-setup/bootstrap.sh
codex
```

---

## 换机器恢复

```bash
npm install --prefix ~/codex @openai/codex@latest
export PATH="$HOME/.local/bin:$PATH"
git clone git@github.com:1Keria/Codex_config.git ~/codex-setup
cp ~/codex-setup/.env.example ~/codex-setup/.env   # 填 OPENAI_API_KEY
~/codex-setup/bootstrap.sh
codex
```

`bootstrap.sh` 会：加载密钥 → 装 PATH 包装器 → 把 `settings.json` / MCP 生成到 `~/.codex/config.toml` → 同步 AGENTS.md / skills → 恢复 plugin。

---

## 日常

```bash
# 改模型 / 端点
# 编辑 settings.json 后：
~/codex-setup/bootstrap.sh

# Plugin
~/codex-setup/scripts/add-plugin.sh github@openai-curated

# Skill
~/codex-setup/scripts/add-skill.sh my-skill /path/to/skill

# MCP（JSON，和 claude-setup 一样）
~/codex-setup/scripts/add-mcp.sh github \
  '{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN}"}}'
~/codex-setup/bootstrap.sh
```

---

## 什么进 Git、什么不进

| 进 Git | 不进 Git |
|--------|----------|
| `settings.json`（无密钥） | `.env` |
| `plugins.lock`、`marketplaces.lock` | `~/.codex/config.toml`（生成物） |
| `skills/`、`mcp/user-servers.json` | 会话 / 缓存 |
| `AGENTS.md`、`.env.example` | |

---

## 与 claude-setup 对应

| claude-setup | codex-setup |
|--------------|-------------|
| `settings.json` | `settings.json` |
| `ANTHROPIC_BASE_URL` / `ANTHROPIC_MODEL` | `OPENAI_BASE_URL` / `OPENAI_MODEL` |
| `ANTHROPIC_AUTH_TOKEN`（`.env`） | `OPENAI_API_KEY`（`.env`，可复用前者） |
| `CLAUDE.md` | `AGENTS.md` |
| `mcp/user-servers.json` | `mcp/user-servers.json` |
| `~/.claude/skills/` | `~/.agents/skills/` |
| `plugins.lock` | `plugins.lock` |

---

## 常见问题

**连不上？** 确认已 `bootstrap.sh`，`which codex` 为 `~/.local/bin/codex`，`.env` 或 claude-setup 里有 Key，`settings.json` 的 URL/模型正确。

**还要 `codex login` 吗？** 用 Auto-Code 时不需要。

**Plugin 没有命令？** 需要 Codex >= 0.137：`npm install --prefix ~/codex @openai/codex@latest && ~/codex-setup/bootstrap.sh`
