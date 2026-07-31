# Codex 个人配置仓库

用 Git 管理 Codex CLI 的**个人全局配置**，结构仿照 `~/claude-setup`，方便在多台机器之间迁移。

远程仓库：[github.com/1Keria/Codex_config](https://github.com/1Keria/Codex_config)

简短说明见 [`DESCRIPTION.md`](./DESCRIPTION.md)。

---

## 本仓库管理什么


| 类型           | 仓库中的位置                               | 机器上的位置                                         |
| ------------ | ------------------------------------ | ---------------------------------------------- |
| **第三方 API**  | `config.toml`（端点/模型）+ `.env`（密钥）     | `~/.codex/config.toml` + PATH 包装器注入环境变量        |
| **Plugin**   | `plugins.lock` + `marketplaces.lock` | `~/.codex/` 插件缓存（`codex plugin` 自动管理）          |
| **独立 Skill** | `skills/<名字>/`                       | `~/.agents/skills/<名字>/`（符号链接）                 |
| **独立 MCP**   | `mcp/user-servers.toml`              | 合并进 `~/.codex/config.toml` → `[mcp_servers.*]` |
| **个人偏好**     | `AGENTS.md`                          | `~/.codex/AGENTS.md`                           |


---

## 目录结构

```
codex-setup/
├── bootstrap.sh              # 新机器一键恢复（核心脚本）
├── README.md
├── .env                      # 本地密钥（不进 Git）
├── .env.example              # 密钥模板
├── .gitignore
│
├── config.toml               # API 端点、模型、sandbox、provider
├── AGENTS.md                 # 全局个人偏好
│
├── plugins.lock              # 已安装的 plugin 清单
├── marketplaces.lock         # 已添加的 marketplace 清单
│
├── skills/                   # 独立 skill
│   └── <skill-name>/
│       └── SKILL.md
│
├── mcp/
│   ├── user-servers.toml     # 独立 MCP 配置
│   └── user-servers.example.toml
│
└── scripts/
    ├── add-plugin.sh
    ├── add-marketplace.sh
    ├── add-skill.sh
    └── add-mcp.sh
```

---



## 第三方 API 登录（Auto-Code）

本仓库默认配置 [Auto-Code](https://vip.auto-code.net) 作为 Codex 的模型来源，**无需运行** `codex login`。

### 配置说明


| 配置项     | 存放位置                                                   | 说明                                                 |
| ------- | ------------------------------------------------------ | -------------------------------------------------- |
| API 地址  | `config.toml` → `[model_providers.auto-code].base_url` | 当前：`https://vip.auto-code.net/v1`                  |
| 默认模型    | `config.toml` → `model`                                | 当前：`gpt-5.5`                                       |
| API Key | `.env` → `OPENAI_API_KEY`                              | 或复用 `~/claude-setup/.env` 的 `ANTHROPIC_AUTH_TOKEN` |


> Codex 通过自定义 `model_provider` + `env_key` 连接网关。`bootstrap.sh` 会安装 `~/.local/bin/codex` 包装器，启动时自动加载密钥。



### 密钥从哪里来？

两种方式任选其一：

```bash

cd ~/codex-setup
cp .env.example .env
# 编辑 .env：
# OPENAI_API_KEY=sk-xxxxxxxx

~/codex-setup/bootstrap.sh
```



### 验证是否可用

```bash
codex --version
codex exec -m gpt-5.5 "用一句话介绍你自己"
codex    # 启动交互式会话
```



### 密钥安全

- `.env` 已在 `.gitignore` 中，**切勿提交到 Git**
- API Key 只写在 `.env`（或复用 claude-setup），`config.toml` 里不含密钥
- 若密钥泄露，请到服务商后台轮换

---



## 快速开始（当前机器）

```bash
# 1. 确认已安装 Codex（本机已有 ~/codex）
#    若没有: npm install -g @openai/codex@latest
#    或: mkdir -p ~/codex && npm install --prefix ~/codex @openai/codex@latest

# 2. （可选）单独配置 API Key；否则复用 claude-setup
# cp ~/codex-setup/.env.example ~/codex-setup/.env

# 3. 一键恢复
~/codex-setup/bootstrap.sh

# 4. 启动
codex
```

---



## 换机器恢复（完整流程）

```bash
# 1. 安装 Node / Codex
npm install --prefix ~/codex @openai/codex@latest
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$HOME/.npm-global/bin:$PATH"

# 2. 克隆配置仓库
git clone git@github.com:1Keria/Codex_config.git ~/codex-setup

# 3. 配置密钥（或同步 claude-setup/.env）
cp ~/codex-setup/.env.example ~/codex-setup/.env
# 编辑 OPENAI_API_KEY

# 4. 一键恢复
~/codex-setup/bootstrap.sh

# 5. 验证
codex --version
codex exec -m gpt-5.5 "hi"
codex
```



### bootstrap.sh 会自动完成

1. 定位 Codex 二进制（优先 `~/codex/node_modules/.bin/codex`）
2. 安装 `~/.local/bin/codex` 包装器（自动加载 API Key）
3. 加载 `.env` / 复用 `~/claude-setup/.env`
4. 将 `config.toml` + `mcp/user-servers.toml` 合并写入 `~/.codex/config.toml`
5. 将 `AGENTS.md` 同步到 `~/.codex/AGENTS.md`
6. 将 `skills/` 链接到 `~/.agents/skills/`
7. 添加 `marketplaces.lock` 中的 marketplace，安装 `plugins.lock` 中的 plugin（需 Codex >= 0.137）

---



## 日常：安装新东西



### 安装 Plugin（来自 marketplace）

```bash
# 推荐：辅助脚本（自动写入 plugins.lock）
~/codex-setup/scripts/add-plugin.sh github@openai-curated

# 或手动安装后记录
codex plugin add linear@openai-curated
echo "linear@openai-curated" >> ~/codex-setup/plugins.lock
```

添加第三方 marketplace：

```bash
~/codex-setup/scripts/add-marketplace.sh owner/repo
# 或
codex plugin marketplace add anthropics/example-plugins
echo "anthropics/example-plugins" >> ~/codex-setup/marketplaces.lock
```

查看与验证：

```bash
codex plugin marketplace list
codex plugin list
```

提交变更：

```bash
cd ~/codex-setup
git add plugins.lock marketplaces.lock
git commit -m "add plugins"
```



### 安装独立 Skill

```bash
~/codex-setup/scripts/add-skill.sh my-skill /path/to/skill-source

cd ~/codex-setup
git add skills/my-skill
git commit -m "add skill: my-skill"
```



### 安装独立 MCP

```bash
~/codex-setup/scripts/add-mcp.sh github npx -y @modelcontextprotocol/server-github
# 在 .env 中配置 GITHUB_PERSONAL_ACCESS_TOKEN，并在 user-servers.toml 里加 env 表（参考 example）
~/codex-setup/bootstrap.sh
```

或直接编辑 `mcp/user-servers.toml` 后运行 `bootstrap.sh`。

---



## 什么进 Git、什么不进


| 进 Git                              | 不进 Git                    |
| ---------------------------------- | ------------------------- |
| `config.toml`（端点、模型，**无密钥**）       | `.env`（API Key、MCP 密钥）    |
| `plugins.lock`、`marketplaces.lock` | `~/.codex/` 插件缓存          |
| `skills/`                          | `~/.codex/auth.json`、会话记录 |
| `mcp/user-servers.toml`            | 缓存、telemetry              |
| `AGENTS.md`、`.env.example`         |                           |


---



## 与 claude-setup 的对应关系


| claude-setup                               | codex-setup                                           |
| ------------------------------------------ | ----------------------------------------------------- |
| `settings.json`                            | `config.toml`                                         |
| `CLAUDE.md`                                | `AGENTS.md`                                           |
| `~/.claude/skills/`                        | `~/.agents/skills/`                                   |
| `mcp/user-servers.json` → `~/.claude.json` | `mcp/user-servers.toml` → `~/.codex/config.toml`      |
| `ANTHROPIC_*`                              | `OPENAI_API_KEY` + `model_providers.auto-code`        |
| `plugins.lock` / `marketplaces.lock`       | 同名 lock + `codex plugin` / `codex plugin marketplace` |


---



## 常见问题



### API 连接失败 / 模型不可用？

- 确认包装器可用：`which codex` 应为 `~/.local/bin/codex`
- 确认密钥：包装器会加载 `codex-setup/.env` 或映射 `claude-setup` 的 token
- 确认已运行 `bootstrap.sh`
- 检查 `config.toml` 中 `base_url` / `model` 是否正确
- 若网关不支持 Responses API，可将 `wire_api` 改为 `"chat"` 后重新 bootstrap



### 还需要 `codex login` 吗？

使用 Auto-Code 等第三方 API 时**不需要**（`requires_openai_auth = false`）。若改回 OpenAI 官方 ChatGPT 订阅，调整 `config.toml` 后运行 `codex login`。

### Skill 不生效？

- 确认 `skills/<name>/SKILL.md` 存在
- 检查链接：`ls -la ~/.agents/skills/`
- 重新运行 `bootstrap.sh`，新开 Codex 会话



### MCP 不生效？

- 确认 `mcp/user-servers.toml` 含 `[mcp_servers.*]`
- 确认 `.env` 中对应密钥已配置
- 运行 `codex mcp list` 检查状态
- 重新运行 `bootstrap.sh`



### Plugin 安装失败 / 没有 `codex plugin`？

- 插件 CLI 需要 **Codex >= 0.137**（本仓库建议 `0.146+`）
- 升级：`npm install --prefix ~/codex @openai/codex@latest && ~/codex-setup/bootstrap.sh`
- 确认：`codex --version` 且 `which codex` 为 `~/.local/bin/codex`
- 先添加 marketplace，再 `codex plugin add name@marketplace`
- 官方商店一般为 `openai-curated`

---



## 参考链接

- [Codex 文档](https://developers.openai.com/codex)
- [高级配置 / 自定义 Provider](https://developers.openai.com/codex/config-advanced)
- [Plugins](https://developers.openai.com/codex/plugins)
- [Skills](https://developers.openai.com/codex/skills)
- [AGENTS.md](https://developers.openai.com/codex/guides/agents-md)

