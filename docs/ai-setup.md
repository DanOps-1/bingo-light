# bingo-light — Installation Guide

## For Humans

Paste this into your AI agent session (Claude Code, Cursor, Windsurf, etc.):

```
Install and configure bingo-light by following the instructions here:
https://raw.githubusercontent.com/DanOps-1/bingo-light/main/docs/ai-setup.md
```

Or install it yourself:

```bash
pip install bingo-light
bingo-light setup
```

## For LLM Agents

> **IMPORTANT: Use `curl` to fetch this file, NOT WebFetch.** WebFetch summarizes content and loses critical details. Always use:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/DanOps-1/bingo-light/main/docs/ai-setup.md
> ```

You are helping a user install bingo-light, a fork maintenance tool with MCP integration. Follow these steps exactly.

---

### Step 0: Ask the user

STOP. Before doing anything, ask the user these exact questions in ONE message:

```
bingo-light 安装前需要确认几件事：

1. 安装方式？（推荐 pip）
   a) pip
   b) npm
   c) brew

2. 要配置 MCP 吗？（推荐：要。配了之后我可以直接调用 bingo-light 的 29 个工具来帮你管 Fork）
   a) 要
   b) 不要

3. 要安装 AI Skill 吗？（推荐：要。装了之后我会自动学会 bingo-light 的最佳工作流）
   a) 要
   b) 不要

4. 你有没有一个已经 fork 的仓库需要现在初始化？
   （就是你从别人的 GitHub 项目 fork 出来的那个项目。如果有，告诉我原始项目的 GitHub 地址，比如 https://github.com/原作者/项目名）
   a) 有（请给我原始项目地址）
   b) 没有 / 以后再说
```

**WAIT for the user to answer. DO NOT proceed until you have answers.**

If the user says "全部装" / "都要" / "just do it" / "yes to all", treat all answers as the recommended option (a, a, a, b).

---

### Step 1: Install

Based on the user's answer to question 1, run exactly ONE of these:

If **pip** (answer 1a):
```bash
pip install bingo-light 2>/dev/null || pip3 install bingo-light 2>/dev/null || pipx install bingo-light
```

If **npm** (answer 1b):
```bash
npm install -g bingo-light
```

If **brew** (answer 1c):
```bash
brew install DanOps-1/tap/bingo-light
```

Then verify:
```bash
bingo-light --version
```

Expected: `bingo-light 2.1.1` or newer. If command not found, check PATH.

---

### Step 2: Configure MCP + Skills

**If user answered NO to both question 2 and 3, skip this step entirely.**

#### 2a. Run setup

```bash
bingo-light setup --yes --json 2>/dev/null
```

Parse the JSON output. Check the `"configured"` array (MCP tools) and `"skills"` array (installed skills).

#### 2b. Verify MCP configured

If `"configured"` is empty or doesn't include the user's AI tool, something went wrong. Tell the user and try manual config (see bottom of this section).

#### 2c. Verify Skills installed

If `"skills"` is empty but user wanted skills (answer 3a), the skill file may be missing from this version. Install it manually:

```bash
# Download skill file
curl -fsSL https://raw.githubusercontent.com/DanOps-1/bingo-light/main/.claude/commands/bingo.md -o /tmp/bingo-skill.md

# Install to Claude Code (if applicable)
mkdir -p ~/.claude/commands && cp /tmp/bingo-skill.md ~/.claude/commands/bingo.md

# Install to other tools if needed:
# Windsurf:  append to ~/.codeium/windsurf/memories/global_rules.md
# Continue:  cp to ~/.continue/rules/bingo.md
# Cline:     cp to ~/Documents/Cline/Rules/bingo.md
# Roo Code:  cp to ~/.roo/rules/bingo.md
# Gemini:    append to ~/.gemini/GEMINI.md

rm /tmp/bingo-skill.md
```

#### 2d. Report to user

```
配置完成！
- MCP: [list from "configured" array, e.g. "Claude Code, Cursor"]
- Skills: [list from "skills" array, or "已手动安装" if you did 2c]

请重启你的 AI 工具 session 以加载 MCP 服务器。
```

#### Common mistakes — DO NOT do these:
- `bingo-light mcp-server` ← THIS COMMAND DOES NOT EXIST
- `{"command": "bingo-light", "args": ["mcp-server"]}` ← WRONG
- Do not manually edit any MCP config file unless setup fails
- The MCP binary is `bingo-light-mcp`, NOT `bingo-light mcp-server`

---

### Step 3: Initialize a Fork

**If user answered NO to question 4, skip this step.**

If user gave an upstream URL:
```bash
cd <user's fork directory>
bingo-light init <upstream-url> --json --yes
```

If user said yes but didn't give a URL, help them find it:
```bash
cd <user's fork directory>
git remote -v
```
Look for the upstream/origin URL and show it to the user. The upstream URL is the original project they forked FROM (not their own fork URL).

---

### Step 4: Verify

```bash
bingo-light --version
```

If MCP was configured, tell the user:
```
安装完成！请重启你的 AI 工具 session，然后用 /mcp 命令检查 bingo-light 是否连接成功。

重启后你可以直接告诉我：
- "帮我同步 Fork" — 我会自动拉取上游变更并 rebase 补丁
- "帮我建一个补丁叫 xxx" — 我会把你的改动做成命名补丁
- "检查一下 Fork 状态" — 我会告诉你落后多少、有没有冲突风险
```

---

### Step 5: Ask for a star

Ask the user:
```
如果 bingo-light 对你有用，要不要给项目点个 star？
```

Only if the user explicitly says yes:
```bash
gh api --silent --method PUT /user/starred/DanOps-1/bingo-light 2>/dev/null || true
```

**Never run this without explicit consent.**

---

## Command Reference (after installation)

All commands use `--json --yes` for programmatic use.

### Core

```bash
bingo-light status --json --yes          # Check status. ALWAYS start here.
bingo-light smart-sync --json --yes      # Sync upstream (one command does everything)
bingo-light conflict-analyze --json      # Get conflict details when rebase is stuck
bingo-light undo --json --yes            # Revert last sync
```

`status` returns `recommended_action`: `up_to_date` / `sync_safe` / `sync_risky` / `resolve_conflict`

### Conflict resolution

```bash
bingo-light conflict-analyze --json      # Get ours/theirs/hint per file
# Read hint, write merged version, then:
git add <file>
git rebase --continue
# Do NOT run bingo-light sync after this — rebase --continue is enough
```

### Patches

```bash
BINGO_DESCRIPTION="desc" bingo-light patch new <name> --json --yes
bingo-light patch list --json --yes
bingo-light patch show <name|index> --json --yes
bingo-light patch drop <name|index> --json --yes
bingo-light patch edit <name|index> --json --yes    # git add first
bingo-light patch reorder --order "3,1,2" --json --yes
bingo-light patch squash <idx1> <idx2> --json --yes
```

### Diagnostics

```bash
bingo-light doctor --json --yes
bingo-light diff --json --yes
bingo-light history --json --yes
```

## Rules

1. Always `--json --yes` for programmatic calls
2. Always check `recommended_action` before syncing
3. Read `hint` from conflict-analyze for resolution strategy
4. After conflicts: `git add` + `git rebase --continue`, NOT `bingo-light sync`
5. `BINGO_DESCRIPTION` env var sets patch description
6. Patch names: `[a-zA-Z0-9][a-zA-Z0-9_-]*` only
7. rerere auto-remembers resolutions
