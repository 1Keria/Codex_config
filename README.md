# Codex 统一配置仓库

本仓库已经整合两部分能力：

1. `qz_codex/`：qz 平台离线安装、云豆 API、HTTP/SSE、端口映射、共享持久化；
2. 仓库根配置：`AGENTS.md`、MCP、Skills、Plugins、Marketplaces。

统一入口：

```bash
bash script/codex/bootstrap.sh <命令>
```

## 快速使用

### 可上网区

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/bootstrap.sh internet
```

如果 qz 映射 URL 变化：

```bash
CODEX_PROXY_BASE_URL="新的完整映射地址" \
  bash script/codex/bootstrap.sh internet
```

### 不可上网区第一次或新容器恢复

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/bootstrap.sh install
bash script/codex/bootstrap.sh check
```

### 日常使用

```bash
cd 你的Git项目
codex
```

非 Git 目录：

```bash
codex --skip-git-repo-check
```

## bootstrap 子命令

| 命令 | 作用 |
|---|---|
| `bootstrap.sh install` | 验证映射、安装 Codex、生成云豆 Provider、同步全部个人配置 |
| `bootstrap.sh sync` | 只同步 AGENTS/MCP/skills/plugins，不重装 Codex、不覆盖 Provider |
| `bootstrap.sh check` | 检查版本、持久目录和最小模型请求 |
| `bootstrap.sh internet` | 可上网区准备离线包并启动 `16067` 代理 |

省略子命令等同于 `install`。

## 配置职责

| 内容 | 管理位置 |
|---|---|
| API 地址、Key、默认模型 | `qz_codex/codex.api.env`（Git 忽略） |
| qz 映射地址 | `offline_repo/codex/proxy.env` |
| 云豆 Provider / HTTP-SSE | `qz_codex/install_codex_offline.sh` 生成 |
| 个人全局指令 | `AGENTS.md` |
| MCP | `mcp/user-servers.json` |
| Skills | `skills/<name>/` |
| Plugins | `plugins.lock` |
| Marketplaces | `marketplaces.lock` |
| 兼容元数据 | `settings.json`（不再生成 Provider） |

运行时统一写入：

```text
/inspire/hdd/project/inference-chip/czxs25240022/apps/codex/home
```

`bootstrap.sh sync` 只替换 `config.toml` 中带以下标记的 MCP 区块：

```text
# >>> codex-config managed MCP >>>
# <<< codex-config managed MCP <<<
```

不会覆盖：

```toml
model_provider = "yundou"
supports_websockets = false
```

## 管理 MCP

```bash
bash script/codex/scripts/add-mcp.sh github \
  '{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN}"}}'

bash script/codex/bootstrap.sh sync
```

注意：不可上网区不能动态下载 `npx -y` 包；MCP 依赖需要提前放在共享目录或使用已安装的绝对路径。

## 管理 Skill

```bash
bash script/codex/scripts/add-skill.sh my-skill /path/to/skill
bash script/codex/bootstrap.sh sync
```

Skill 真实内容保存在本仓库；持久 Home 和 `~/.agents/skills` 仅创建可重建软链接。

## 管理 Plugin / Marketplace

```bash
bash script/codex/scripts/add-marketplace.sh owner/repo
bash script/codex/scripts/add-plugin.sh plugin@marketplace
```

锁文件会用于后续 `bootstrap.sh sync` 恢复。不可上网区恢复远程 Marketplace 需要其内容已缓存或网络可达。

## 目录结构

```text
script/codex/
├── bootstrap.sh                 # 统一入口
├── README.md                    # 本文档
├── AGENTS.md                    # 全局个人指令
├── settings.json                # 兼容说明，不管理 Provider
├── mcp/
│   └── user-servers.json
├── skills/
├── scripts/
│   ├── add-mcp.sh
│   ├── add-skill.sh
│   ├── add-plugin.sh
│   └── add-marketplace.sh
├── plugins.lock
├── marketplaces.lock
└── qz_codex/
    ├── README.md                # qz 部署详细说明
    ├── setup_internet_codex.sh
    ├── setup_offline_codex.sh
    ├── sync_personal_config.sh
    ├── check_codex.sh
    └── ...
```

## 持久化与安全

以下真实数据位于共享项目目录，不依赖个人 Home：

```text
apps/codex/home/          # 配置、会话、状态、skills
apps/codex/               # CLI 与原生二进制
offline_repo/codex/       # 离线包
apps/claude/              # HTTP/SSE 代理与持久依赖
```

敏感文件不进入 Git：

```text
qz_codex/codex.api.env
.env
```

完整 qz 部署、环境切换、故障排查和升级说明见：

```text
qz_codex/README.md
```
