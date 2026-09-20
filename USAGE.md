# Codex 使用手册

本文档只说明实际使用方式。项目设计与实现细节见 `README.md`，qz 部署细节见 `qz_codex/README.md`。

## 1. 先判断使用哪种模式

| 运行环境 | 模式 | 命令 |
|---|---|---|
| qz 平台不可上网区 | `qz` | `bash script/codex/bootstrap.sh qz` |
| 普通机器，可直接访问 `yundou.ai` | `direct` | `bash bootstrap.sh direct` |
| 只更新 AGENTS、MCP、Skills、Plugins | 公共同步 | `bash bootstrap.sh sync` |

两种模式使用独立的 API 配置、运行时 Home、会话和状态，不会互相覆盖。

---

## 2. qz 平台使用方式

qz 的可上网区与不可上网区必须能看到同一个共享项目目录：

```text
/inspire/hdd/project/inference-chip/czxs25240022
```

### 2.1 可上网区

进入共享项目目录：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
```

准备 Codex 离线包并启动 `16067` API 代理：

```bash
bash script/codex/bootstrap.sh internet
```

检查代理：

```bash
curl http://127.0.0.1:16067/health
```

预期：

```json
{"status":"ok","target":"https://yundou.ai/v1"}
```

在 qz 平台将该资源的 `16067` 端口映射出去。

如果平台生成了新的映射 URL，执行：

```bash
CODEX_PROXY_BASE_URL="https://完整映射地址/proxy/16067" \
  bash script/codex/bootstrap.sh internet
```

映射地址会保存在共享目录：

```text
offline_repo/codex/proxy.env
```

### 2.2 不可上网区

进入同一共享目录：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
```

安装或恢复 qz 模式：

```bash
bash script/codex/bootstrap.sh qz
```

完整自检：

```bash
bash script/codex/bootstrap.sh check
```

成功示例：

```text
[OK] codex-cli 0.155.1；模式=qz；持久目录=.../apps/codex/home；模型调用正常
```

之后进入代码项目直接使用：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022/你的项目
codex
```

---

## 3. 非 qz 环境直连方式

适用于能够直接访问：

```text
https://yundou.ai/v1
```

的普通 Linux 机器。

### 3.1 准备 API Key

方式一：临时环境变量：

```bash
export CODEX_API_KEY="你的云豆API密钥"
```

方式二：在 Codex_config 仓库创建 `.env`：

```bash
cd /path/to/Codex_config
cp .env.example .env
```

编辑 `.env`：

```bash
CODEX_API_KEY=你的云豆API密钥
```

`.env` 已被 Git 忽略。

### 3.2 安装并启用 direct 模式

在 Codex_config 仓库根目录执行：

```bash
cd /path/to/Codex_config
bash bootstrap.sh direct
```

自检：

```bash
bash bootstrap.sh check
```

成功示例：

```text
[OK] codex-cli 0.155.1；模式=direct；持久目录=.../.runtime/direct/home；模型调用正常
```

然后在任意代码项目中：

```bash
cd /path/to/your-project
codex
```

普通机器若尚未安装 Codex，direct 脚本需要系统已有 Node.js 和 npm，并会安装固定版本 Codex。

---

## 4. 日常 Codex 命令

### 交互模式

在 Git 项目中：

```bash
codex
```

在非 Git 目录中：

```bash
codex --skip-git-repo-check
```

### 一次性执行任务

Git 项目：

```bash
codex exec "请分析当前项目结构"
```

非 Git 目录：

```bash
codex exec --skip-git-repo-check "请分析当前目录"
```

### JSON 输出

```bash
codex exec --skip-git-repo-check --json "只回复 OK"
```

### 临时切换模型

默认模型是 `gpt-5.6`。临时切换：

```bash
codex exec \
  --skip-git-repo-check \
  -c 'model="gpt-5.6-sol"' \
  "请分析当前项目"
```

提示词直接写在命令末尾。不要使用：

```bash
codex -p "提示词"
```

当前 Codex 中 `-p` 表示 profile，不表示 prompt。

---

## 5. 公共配置同步

qz 和 direct 共用以下 Git 配置：

```text
AGENTS.md
mcp/user-servers.json
skills/
plugins.lock
marketplaces.lock
```

同步所有已经安装的模式：

```bash
bash script/codex/bootstrap.sh sync
```

如果当前就在 Codex_config 仓库根目录：

```bash
bash bootstrap.sh sync
```

`sync` 会：

- 同步 `AGENTS.md`；
- 合并 MCP 配置；
- 链接 Skills；
- 恢复 Plugins 和 Marketplaces；
- 同时更新已安装的 qz Home 和 direct Home；
- 不切换当前模式；
- 不覆盖 API 地址、模型 Provider 或 WebSocket 设置。

---

## 6. 添加 MCP

示例：

```bash
bash script/codex/scripts/add-mcp.sh github \
  '{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN}"}}'
```

然后同步：

```bash
bash script/codex/bootstrap.sh sync
```

MCP 密钥放在 Git 忽略的：

```text
script/codex/.env
```

例如：

```bash
GITHUB_PERSONAL_ACCESS_TOKEN=你的GitHub密钥
```

不可上网区不能临时从 npm 下载 MCP 包。需要提前安装依赖或使用共享目录中的绝对命令路径。

---

## 7. 添加 Skill

```bash
bash script/codex/scripts/add-skill.sh my-skill /path/to/skill
```

Skill 源目录必须包含：

```text
SKILL.md
```

添加后脚本会调用公共同步，将 Skill 链接到所有已安装模式。

也可以手动放入：

```text
script/codex/skills/my-skill/
```

然后执行：

```bash
bash script/codex/bootstrap.sh sync
```

---

## 8. 切换模式

切换到 qz：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/bootstrap.sh qz
```

切换到 direct：

```bash
cd /path/to/Codex_config
bash bootstrap.sh direct
```

确认当前模式并测试模型：

```bash
bash script/codex/bootstrap.sh check
```

或在仓库根目录：

```bash
bash bootstrap.sh check
```

输出会包含：

```text
模式=qz
```

或：

```text
模式=direct
```

---

## 9. 持久化位置

### qz 模式

```text
/inspire/hdd/project/inference-chip/czxs25240022/apps/codex/home
```

保存 qz 配置、会话、状态数据库、Skills 和 Shell snapshots。

### direct 模式

```text
Codex_config/.runtime/direct/home
```

保存 direct 配置、会话、状态数据库和 Skills。

### 公共 Git 配置

```text
script/codex/AGENTS.md
script/codex/mcp/
script/codex/skills/
script/codex/plugins.lock
script/codex/marketplaces.lock
```

### 敏感配置

```text
qz_codex/codex.api.env
direct_codex/codex.direct.env
.env
```

这些文件都已被 Git 忽略。

---

## 10. 常见故障

### `codex: command not found`

重新启用对应模式：

```bash
bash script/codex/bootstrap.sh qz
```

或者：

```bash
bash bootstrap.sh direct
```

### `Not inside a trusted directory`

```bash
codex --skip-git-repo-check
```

或者：

```bash
codex exec --skip-git-repo-check "你的任务"
```

### qz 映射失效

在可上网区更新映射：

```bash
CODEX_PROXY_BASE_URL="新的完整映射地址" \
  bash script/codex/bootstrap.sh internet
```

然后在不可上网区：

```bash
bash script/codex/bootstrap.sh qz
bash script/codex/bootstrap.sh check
```

### direct 无法连接

测试：

```bash
curl -I https://yundou.ai/v1/models
```

然后重新执行：

```bash
bash bootstrap.sh direct
```

### 出现 WebSocket 重连

检查当前 Home 的 `config.toml` 是否包含：

```toml
model_provider = "yundou"
supports_websockets = false
```

重新运行当前模式的安装命令即可修复。

### `Model metadata for gpt-5.6 not found`

这是非致命警告。云豆模型调用已经验证可正常完成。

### bubblewrap 警告

Codex 会使用安装包自带的 bubblewrap，通常不影响使用。

---

## 11. 推荐操作速查

### qz

```bash
# 可上网区
bash script/codex/bootstrap.sh internet

# 不可上网区
bash script/codex/bootstrap.sh qz
bash script/codex/bootstrap.sh check

# 使用
cd 你的项目
codex
```

### 非 qz 直连

```bash
export CODEX_API_KEY="你的云豆Key"
bash bootstrap.sh direct
bash bootstrap.sh check

cd /path/to/project
codex
```

### 同步公共配置

```bash
bash script/codex/bootstrap.sh sync
```
