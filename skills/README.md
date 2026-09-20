# 独立 Skills 目录

每个 Skill 使用一个子目录，必须包含 `SKILL.md`：

```text
skills/
└── my-skill/
    ├── SKILL.md
    ├── references/      # 可选
    └── scripts/         # 可选
```

添加 Skill：

```bash
cd /inspire/hdd/project/inference-chip/czxs25240022
bash script/codex/scripts/add-skill.sh my-skill /path/to/source
```

脚本会：

1. 将 Skill 内容复制到本 Git 仓库的 `skills/my-skill/`；
2. 链接到持久目录 `apps/codex/home/skills/my-skill`；
3. 创建兼容链接 `~/.agents/skills/my-skill`（个人目录丢失后可由 bootstrap 重建）。

重新同步全部 Skill：

```bash
bash script/codex/bootstrap.sh sync
```

真实内容始终保存在 Git 仓库，运行时链接和个人目录都可以重建。
