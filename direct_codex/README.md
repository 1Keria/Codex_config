# 非 qz 直连模式

用于能够直接访问 `https://yundou.ai/v1` 的普通机器，不需要 qz 端口映射和可上网区代理。

## 首次使用

```bash
cd /path/to/Codex_config
bash bootstrap.sh direct
bash bootstrap.sh check
```

首次运行需要 API Key。任选一种方式：

```bash
export CODEX_API_KEY="你的云豆Key"
bash bootstrap.sh direct
```

或创建 Git 忽略的根 `.env`：

```bash
cp .env.example .env
# 编辑 .env，填写 CODEX_API_KEY
bash bootstrap.sh direct
```

如果同一共享目录已经配置 qz，首次运行也可复用 `qz_codex/codex.api.env` 中的 Key。

## 持久化

直连模式的运行时位于：

```text
script/codex/.runtime/direct/
├── app/       # 普通机器通过 npm 安装的 Codex（如需）
├── bin/codex  # 直连入口
└── home/      # 配置、会话、状态、skills
```

直连密钥配置：

```text
direct_codex/codex.direct.env
```

以上路径均被 Git 忽略。真实数据不依赖个人 Home；`~/.codex` 仅是当前模式的兼容软链接。

## 使用

```bash
codex
codex exec "请分析当前项目"
```

非 Git 目录：

```bash
codex --skip-git-repo-check
```

## 公共个人配置

qz 与 direct 共用同一套 Git 配置：

```text
AGENTS.md
mcp/user-servers.json
skills/
plugins.lock
marketplaces.lock
```

同步所有已安装模式：

```bash
bash bootstrap.sh sync
```

同步不会切换当前模式，也不会覆盖任何模式的 Provider。

## 切换回 qz

在 qz 共享项目目录执行：

```bash
bash script/codex/bootstrap.sh qz
bash script/codex/bootstrap.sh check
```
