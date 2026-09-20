# qz 平台 Codex 使用说明

本目录用于在 qz 平台的**可上网区 + 不可上网区**之间部署和使用 OpenAI Codex CLI。

当前已验证组合：

- Codex CLI / Harness：`0.155.1`
- 默认模型：`gpt-5.6`
- API：云豆 OpenAI-compatible Responses API
- 传输：HTTP/SSE
- WebSocket：关闭
- 可上网区和不可上网区共享同一个项目目录

项目根目录：

```text
/inspire/hdd/project/inference-chip/czxs25240022
```

---

## 1. 工作原理

```text
不可上网区 Codex Harness
        │
        │ HTTPS（qz 端口映射）
        ▼
可上网区 :16067 HTTP/SSE 代理
        │
        ▼
https://yundou.ai/v1
```

Codex 使用自定义 `yundou` Provider，而不是内置的 `openai` Provider：

```toml
model_provider = "yundou"
wire_api = "responses"
supports_websockets = false
```

因此会保留完整 Codex Harness（文件工具、Shell、Git、MCP、会话等），同时避免连接官方 Responses WebSocket。

**VPN 不是此方案的依赖。** 云豆请求不需要开启 VPN。

---

## 2. 脚本说明

| 脚本 | 运行区域 | 作用 |
|---|---|---|
| `setup_internet_codex.sh` | 可上网区 | 准备/复用离线包和代理依赖，启动或复用 `16067` 代理 |
| `setup_offline_codex.sh` | 不可上网区 | 验证 qz 映射，安装 Codex，生成持久配置和命令入口 |
| `sync_personal_config.sh` | 任意区域 | 合并根目录 AGENTS、MCP、skills、plugins，不覆盖 Provider |
| `check_codex.sh` | 任意区域 | 检查版本、持久目录并执行最小模型请求 |
| `run_codex.sh` | 任意区域 | 兼容性启动器；缺少安装时自动安装，否则直接启动 Codex |
| `prepare_codex_offline.sh` | 可上网区 | 准备固定版本 `0.155.1` 的两个离线 tgz |
| `install_codex_offline.sh` | 任意区域 | 从共享离线包安装 Codex 并重建所有入口和配置 |
| `start_codex_offline.sh` | 任意区域 | 兼容旧用法，向当前 Shell 导出环境；日常使用不需要执行 |

---

## 3. 第一次配置

### 3.1 可上网区启动代理

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/qz_codex/setup_internet_codex.sh
```

该脚本会：

1. 检查并复用 `Codex 0.155.1` 离线包；
2. 使用 `apps/claude/python-packages/` 中的持久化代理依赖；
3. 在 `0.0.0.0:16067` 启动 HTTP/SSE 代理；
4. 将请求转发到 `https://yundou.ai/v1`；
5. 保留已有的 qz 公网映射地址，不会用内网 IP 覆盖它。

本机健康检查：

```bash
curl http://127.0.0.1:16067/health
```

预期：

```json
{"status":"ok","target":"https://yundou.ai/v1"}
```

### 3.2 在 qz 平台映射端口

在可上网区 Notebook/资源的端口管理中映射：

```text
端口：16067
协议：HTTP（平台仅提供 TCP 时选 TCP）
```

平台会生成类似以下地址：

```text
https://.../proxy/16067/
```

配置时应去掉末尾 `/`。

如果映射地址发生变化，在可上网区执行：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
CODEX_PROXY_BASE_URL="新的完整映射地址" \
  bash script/codex/qz_codex/setup_internet_codex.sh
```

该地址会保存到：

```text
offline_repo/codex/proxy.env
```

### 3.3 不可上网区安装

切换到不可上网资源后执行：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/qz_codex/setup_offline_codex.sh
```

该脚本会按顺序：

1. 从 `offline_repo/codex/proxy.env` 读取 qz 映射地址；
2. 更新本地 API 配置；
3. 使用 API Key 请求映射地址的 `/models`；
4. 只有连通性和鉴权成功后才继续安装；
5. 从共享离线包安装 Codex `0.155.1`；
6. 生成 `apps/codex/home/config.toml`；
7. 配置 `yundou` Provider、HTTP/SSE 和 `supports_websockets=false`；
8. 创建项目入口和系统命令软链接；
9. 同步根目录的 AGENTS、MCP、skills、plugins。

### 3.4 完整自检

```bash
bash /inspire/hdd/project/inference-chip/czxs25240022/script/codex/qz_codex/check_codex.sh
```

成功示例：

```text
[OK] codex-cli 0.155.1；持久目录=.../apps/codex/home；模型调用正常
```

---

## 4. 日常使用

### 4.1 在 Git 项目中交互使用

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022/你的项目
codex
```

### 4.2 在非 Git 目录中使用

```bash
codex --skip-git-repo-check
```

### 4.3 执行一次任务

Git 项目：

```bash
codex exec "请分析当前项目结构"
```

非 Git 目录：

```bash
codex exec --skip-git-repo-check "请分析当前目录"
```

### 4.4 输出 JSON

```bash
codex exec --skip-git-repo-check --json "只回复 OK"
```

### 4.5 临时切换模型

默认模型为 `gpt-5.6`。临时切换：

```bash
codex exec \
  --skip-git-repo-check \
  -c 'model="gpt-5.6-sol"' \
  "请分析当前项目"
```

不要使用旧版写法：

```bash
codex -p "提示词"
```

在当前 Codex 中，`-p` 表示 profile，提示词应直接作为位置参数。

---

## 5. 环境切换流程

### 切换或重启可上网区

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/qz_codex/setup_internet_codex.sh
```

如果 qz 平台重新生成了映射地址：

```bash
CODEX_PROXY_BASE_URL="新的完整映射地址" \
  bash script/codex/qz_codex/setup_internet_codex.sh
```

### 切换或重启不可上网区

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/qz_codex/setup_offline_codex.sh
bash script/codex/qz_codex/check_codex.sh
```

之后直接使用：

```bash
codex
```

如果新容器中 `/usr/local/bin/codex` 尚未恢复，可使用始终保存在共享目录中的入口：

```bash
/inspire/hdd/project/inference-chip/czxs25240022/.bin/codex
```

---

## 6. 持久化位置

所有需要跨容器、跨资源区保留的内容都位于共享项目目录。

| 内容 | 路径 |
|---|---|
| Codex CLI、Node 和原生二进制 | `apps/codex/`、`apps/node/` |
| Codex 配置、会话、状态库、skills | `apps/codex/home/` |
| Codex 持久入口 | `.bin/codex` |
| Codex 离线 tgz | `offline_repo/codex/` |
| API 地址、Key、默认模型 | `script/codex/qz_codex/codex.api.env` |
| qz 公网映射地址 | `offline_repo/codex/proxy.env` |
| HTTP 代理代码和依赖 | `apps/claude/proxy.py`、`apps/claude/python-packages/` |
| 代理日志 | `log/codex_yundou_proxy.log` |

个人目录兼容项：

```text
/root/.codex → apps/codex/home/（软链接）
```

系统入口：

```text
/usr/local/bin/codex → apps/codex/bin/codex
/usr/bin/codex       → apps/codex/bin/codex
```

这些软链接可以随时通过 `setup_offline_codex.sh` 重建，真实数据不在个人目录或系统目录中。

> 不要同时在两个资源区运行会写入同一个 `apps/codex/home/` 的 Codex 进程，以免共享 SQLite 状态库发生竞争。

---

## 7. 配置文件

### API 配置

文件：

```text
script/codex/qz_codex/codex.api.env
```

格式：

```bash
BASE_URL=https://qz映射地址/proxy/16067
API_KEY=你的云豆API密钥
MODEL=gpt-5.6
```

该文件包含密钥，已被 Git 忽略，不得提交或分享。

### Codex Provider 配置

生成位置：

```text
apps/codex/home/config.toml
```

核心内容：

```toml
model = "gpt-5.6"
model_provider = "yundou"
model_reasoning_effort = "low"

[model_providers.yundou]
name = "Yundou"
base_url = "qz映射地址"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
supports_websockets = false
```

不要把 Provider 改回内置 `openai`，否则 Codex 会重新尝试 Responses WebSocket。

---

## 8. 常见问题

### `Codex API 映射不可用`

检查：

1. 可上网区资源是否仍在运行；
2. `16067` 代理是否已启动；
3. qz 映射地址是否过期；
4. `offline_repo/codex/proxy.env` 是否是公网映射，而不是 `10.x` 内网地址；
5. API Key 是否有效。

更新映射地址后重新运行：

```bash
CODEX_PROXY_BASE_URL="新的映射地址" \
  bash script/codex/qz_codex/setup_internet_codex.sh
bash script/codex/qz_codex/setup_offline_codex.sh
```

### `codex: command not found`

重建入口：

```bash
bash /inspire/hdd/project/inference-chip/czxs25240022/script/codex/qz_codex/setup_offline_codex.sh
```

或直接使用：

```bash
/inspire/hdd/project/inference-chip/czxs25240022/.bin/codex
```

### `Not inside a trusted directory`

当前目录不是 Git 仓库：

```bash
codex --skip-git-repo-check
```

或者：

```bash
codex exec --skip-git-repo-check "你的任务"
```

### `Model metadata for gpt-5.6 not found`

这是非致命警告。当前 Codex 内置模型表未包含云豆提供的模型元数据，但已验证请求可以正常完成。

### bubblewrap 警告

如果提示找不到系统 bubblewrap，Codex 会使用安装包自带的 bubblewrap，通常不影响使用。

### `Reconnecting` 或 WebSocket 错误

检查 `apps/codex/home/config.toml` 是否仍为：

```toml
model_provider = "yundou"
supports_websockets = false
```

然后重新执行：

```bash
bash script/codex/qz_codex/setup_offline_codex.sh
```

---

## 9. 更新 Codex

当前准备脚本默认固定为 `0.155.1`。要准备其他版本，可在可上网区执行：

```bash
CODEX_VERSION="目标版本" \
  bash script/codex/qz_codex/prepare_codex_offline.sh
```

更新后在不可上网区执行：

```bash
bash script/codex/qz_codex/setup_offline_codex.sh
bash script/codex/qz_codex/check_codex.sh
```

升级后仍需保留 `yundou` Provider 和 `supports_websockets=false`。

---

## 10. 安全说明

以下文件包含敏感信息，不应进入 Git：

```text
script/codex/qz_codex/codex.api.env
offline_repo/codex/proxy.env
apps/codex/home/
log/
```

API Key 不应写入命令行参数、日志或公开文档。如果 Key 曾在聊天、日志或版本库中明文出现，应立即在服务平台撤销并重新生成。


## 11. 与根配置仓库的整合

推荐统一使用：

```bash
bash script/codex/bootstrap.sh internet   # 可上网区
bash script/codex/bootstrap.sh install    # 不可上网区安装/完整恢复
bash script/codex/bootstrap.sh sync       # 只同步个人配置
bash script/codex/bootstrap.sh check      # 自检
```

根目录配置职责：

```text
AGENTS.md                 全局指令
mcp/user-servers.json     MCP
skills/                   独立 Skills
plugins.lock              Plugins
marketplaces.lock         Marketplaces
```

`sync_personal_config.sh` 只更新 AGENTS、skills 和 `config.toml` 中带标记的 MCP 区块，不会覆盖：

```toml
model_provider = "yundou"
supports_websockets = false
```
