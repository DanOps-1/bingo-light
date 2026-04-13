# bingo-light — AI 安装与使用指南

你是一个 AI 编程助手。用户让你安装和配置 bingo-light，一个 Fork 维护工具。

重要：不要擅自做决定。每一步都要跟用户确认。

## 第一步：安装

先问用户用哪种方式安装（pip / npm / brew），推荐 pip：

```bash
pip install bingo-light --break-system-packages 2>/dev/null || pip install bingo-light
```

验证：
```bash
bingo-light --version
```

## 第二步：配置 MCP 和 Skill

不要直接跑 `bingo-light setup --yes`。

先跑检测，告诉用户检测到了哪些 AI 工具：

```bash
bingo-light setup --json 2>/dev/null
```

然后问用户：
1. "检测到以下 AI 工具：XXX。要配置哪些？"（列出检测到的工具让用户选）
2. "要安装 MCP 服务器吗？（推荐，让 AI 能直接调用 bingo-light 工具）"
3. "要安装 Skill/自定义指令吗？（推荐，教 AI 如何使用 bingo-light）"

用户确认后，再跑交互式 setup（不加 --yes，让用户在终端里自己选）：

```bash
bingo-light setup
```

或者如果用户明确说了"全部装"，才用：

```bash
bingo-light setup --yes
```

如果需要手动配 MCP（用户不想用 setup），在对应的 MCP 配置文件中加：
```json
{
  "mcpServers": {
    "bingo-light": {
      "command": "python3",
      "args": ["-m", "bingo_core._entry"]
    }
  }
}
```

或者用 npx（不需要 pip 安装）：
```json
{
  "mcpServers": {
    "bingo-light": {
      "command": "npx",
      "args": ["-y", "bingo-light-mcp"]
    }
  }
}
```

## 第三步：初始化 Fork

进入用户的 Fork 仓库：
```bash
cd /path/to/forked-project
bingo-light init https://github.com/original/project.git --json --yes
```

## 你能做什么

安装完成后，你可以通过 MCP 工具或 CLI `--json --yes` 完成以下所有操作：

### 核心工作流

1. **检查状态** — 永远先跑这个：
```bash
bingo-light status --json --yes
```
返回 `recommended_action`：`up_to_date` / `sync_safe` / `sync_risky` / `resolve_conflict`

2. **同步上游**（推荐用 smart-sync，一步到位）：
```bash
bingo-light smart-sync --json --yes
```

3. **冲突分析**（rebase 卡住时）：
```bash
bingo-light conflict-analyze --json
```
返回每个冲突文件的 `ours`（上游）、`theirs`（补丁）、`hint`（解决建议）

4. **冲突解决**：
```bash
# 读冲突文件，写合并结果，然后：
git add <file>
git rebase --continue
```

5. **撤销**（搞砸了）：
```bash
bingo-light undo --json --yes
```

### 补丁管理

```bash
BINGO_DESCRIPTION="描述" bingo-light patch new <name> --json --yes   # 建补丁
bingo-light patch list --json --yes                                   # 列出补丁
bingo-light patch show <name|index> --json --yes                      # 查看 diff
bingo-light patch drop <name|index> --json --yes                      # 删补丁
bingo-light patch edit <name|index> --json --yes                      # 改补丁（先 git add）
bingo-light patch reorder --order "3,1,2" --json --yes                # 重排
bingo-light patch squash <idx1> <idx2> --json --yes                   # 合并
bingo-light patch meta <name> [key] [value] --json --yes              # 元数据
```

### 诊断

```bash
bingo-light doctor --json --yes     # 全面诊断
bingo-light diff --json --yes       # 补丁总 diff
bingo-light history --json --yes    # 同步历史
bingo-light log --json --yes        # 简要日志
```

## 关键规则

1. **永远用 `--json --yes`**
2. **先 status，看 `recommended_action` 再决定做什么**
3. **冲突时读 `hint` 字段**，它告诉你怎么解
4. **解冲突后**：`git add` → `git rebase --continue`，不要再跑 `bingo-light sync`
5. **`BINGO_DESCRIPTION` 环境变量**设补丁描述
6. **补丁名**只能字母数字加 `-_`
7. **rerere** 自动记住冲突解法，同样冲突不用解第二次
