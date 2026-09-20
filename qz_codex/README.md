# Codex（API）

**联网区**：能访问 npm（或已有完整 `apps/codex/node_modules`，含 `@openai/codex-linux-x64`）。  
**断网区**：不能外网下载、只用共享盘里的 `offline_repo`。

| 脚本 | 什么时候执行 | 在哪执行 |
|------|----------------|----------|
| `prepare_codex_offline.sh` | 还没有离线 tgz；或缺 **`openai-codex-linux-x64*.tgz`** 需要补齐（仅有主包无法在断网机启动） | **联网区** |
| `install_codex_offline.sh` | 第一次部署；或 `codex` / 原生二进制报 `EACCES`、`Permission denied` | **断网区**（或任意已有离线包的环境） |
| `start_codex_offline.sh` | 每次用 Codex 前加载 `codex.api.env` 并 **export** | **你运行 `codex` 的那台机器**；须 **`source`** 执行 |
| `script/claude/start_api_proxy.sh` | 与 Claude 相同：需要 HTTP 转发到 OpenAI 兼容上游时 | **能访问上游的机器**（多在联网区） |

配置：复制并编辑 `script/codex/codex.api.env`（说明见 `codex.api.env.example`）。  
**端口转发 + 第三方**：与 Claude 相同——联网机 `start_api_proxy.sh` 的 `TARGET_URL` 改为 OpenAI 兼容第三方根；断网机 `BASE_URL` 填平台映射到 `16067` 的 URL。  
**直连第三方**：断网机能访问第三方时，`BASE_URL` 直接填 `https://.../v1` 等。  
每次：`source script/codex/start_codex_offline.sh` → `codex`（勿用 `bash`）。若 source 后终端被关掉，同 Claude 的 `start_*` 修复说明。
