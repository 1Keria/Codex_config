# Codex（API）

**联网区**：能访问 npm（或已有完整 `apps/codex/node_modules`，含 `@openai/codex-linux-x64`）。  
**不可上网区**：不能外网下载，但与联网区共享同一个项目目录，因此直接使用同一份 `offline_repo`，不需要复制安装包。

| 脚本 | 什么时候执行 | 在哪执行 |
|------|----------------|----------|
| `prepare_codex_offline.sh` | 还没有离线 tgz；或缺 **`openai-codex-linux-x64*.tgz`** 需要补齐（仅有主包无法在断网机启动） | **联网区** |
| `install_codex_offline.sh` | 第一次部署；或 `codex` / 原生二进制报 `EACCES`、`Permission denied` | **不可上网区**（或任意已有离线包的环境） |
| `start_codex_offline.sh` | 每次用 Codex 前加载 `codex.api.env` 并 **export** | **你运行 `codex` 的那台机器**；须 **`source`** 执行 |
| `script/claude/start_api_proxy.sh` | 与 Claude 相同：需要 HTTP 转发到 OpenAI 兼容上游时 | **能访问上游的机器**（多在联网区） |

配置：复制并编辑 `script/codex/codex.api.env`（说明见 `codex.api.env.example`）。  
**端口转发 + 第三方**：与 Claude 相同——联网机 `start_api_proxy.sh` 的 `TARGET_URL` 改为 OpenAI 兼容第三方根；断网机 `BASE_URL` 填平台映射到 `16067` 的 URL。  
**直连第三方**：断网机能访问第三方时，`BASE_URL` 直接填 `https://.../v1` 等。  
每次：`source script/codex/qz_codex/start_codex_offline.sh` → `codex`（勿用 `bash`）。若 source 后终端被关掉，同 Claude 的 `start_*` 修复说明。


## 共享目录下的使用流程

联网区和不可上网区共享同一个项目目录时，不需要复制 `offline_repo/codex/` 或脚本。只需在联网区准备离线包，在不可上网区安装：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022

# 联网区执行一次：下载/准备离线包
bash script/codex/qz_codex/prepare_codex_offline.sh

# 不可上网区执行一次：从共享目录解包安装
bash script/codex/qz_codex/install_codex_offline.sh

# 不可上网区每次使用前加载 API 配置
source script/codex/qz_codex/start_codex_offline.sh
codex
```

三个脚本会从 `qz_codex` 的位置正确计算项目根目录，资源统一使用项目根目录下的 `offline_repo/codex/` 和 `apps/codex/`。


## 一键使用

联网区只需执行一次，脚本会准备共享离线包并后台启动 `16067` 代理：

```bash
bash script/codex/qz_codex/setup_internet_codex.sh
```

不可上网区只需执行一次安装配置。联网区脚本会自动把代理地址写入共享目录 `offline_repo/codex/proxy.env`，因此通常不需要手工填写地址：

```bash
bash script/codex/qz_codex/setup_offline_codex.sh
```

如果 qz 平台要求使用专门的端口转发 URL，也可以在不可上网区显式覆盖：

```bash
CODEX_PROXY_BASE_URL="端口转发URL" bash script/codex/qz_codex/setup_offline_codex.sh
```

以后每次直接运行：

```bash
bash script/codex/qz_codex/run_codex.sh
```

也可以直接传 Codex 参数：

```bash
bash script/codex/qz_codex/run_codex.sh -p "请回复：连接测试成功"
```

`setup_offline_codex.sh` 会自动安装共享目录中的 Codex、设置配置文件权限，并检查 API 配置；不会打印 API Key。`run_codex.sh` 会自动加载配置，不需要手动 `source`。
