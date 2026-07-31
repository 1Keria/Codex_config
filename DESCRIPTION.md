# Codex_config

个人 Codex CLI 全局配置仓库：用 Git 管理 API 端点/模型、Plugin、Skill、MCP 与 `AGENTS.md`，并通过 `bootstrap.sh` 在新机器上一键恢复。

- **本地目录**：`~/codex-setup`
- **远程仓库**：https://github.com/1Keria/Codex_config
- **姊妹仓库**：https://github.com/1Keria/Claude_config（Claude Code 同结构配置）

## 快速开始

```bash
git clone git@github.com:1Keria/Codex_config.git ~/codex-setup
# 配置密钥（或复用 ~/claude-setup/.env）
cp ~/codex-setup/.env.example ~/codex-setup/.env
~/codex-setup/bootstrap.sh
codex
```

## 管理范围

| 内容 | 说明 |
|------|------|
| `config.toml` | Auto-Code 等第三方 API、默认模型、sandbox |
| `plugins.lock` / `marketplaces.lock` | Plugin 与 Marketplace 清单 |
| `skills/` | 独立 Skill（链接到 `~/.agents/skills/`） |
| `mcp/user-servers.toml` | 独立 MCP（合并进 `~/.codex/config.toml`） |
| `AGENTS.md` | 全局个人偏好 |
| `.env` | 密钥（不进 Git） |
