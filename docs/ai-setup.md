# bingo-light — Installation Guide

## For Humans

Paste this into your AI agent:

```
Install and configure bingo-light following:
https://raw.githubusercontent.com/DanOps-1/bingo-light/main/docs/ai-setup.md
```

## For LLM Agents

> Fetch with `curl`, not WebFetch. WebFetch summarizes and loses critical details.
> ```bash
> curl -fsSL https://raw.githubusercontent.com/DanOps-1/bingo-light/main/docs/ai-setup.md
> ```

You are helping install bingo-light. Follow the steps below IN ORDER.

Before doing ANYTHING else, say exactly this to the user:

```
bingo-light 安装助手启动！在安装之前，我需要问你几个问题。
```

Do NOT run any install or config commands until you have said this AND completed Step 0.

### Constraints (read BEFORE starting)

- DO NOT run `bingo-light mcp-server` — this command does not exist. The MCP binary is `bingo-light-mcp`.
- DO NOT install anything before Step 0 is complete.
- DO NOT guess user preferences. ASK.
- DO NOT write MCP config JSON manually. Use `bingo-light setup`.
- DO NOT use `python3` to run the MCP server. Use `sys.executable` path from the install.

---

### Step 0: Ask the user (BLOCKING — do not skip)

Ask these 4 questions in ONE message. Save the answers as variables.
If you do not have answers to ALL 4 questions, STOP. Do not execute any commands.

```
安装前确认：

1. 安装方式？
   a) pip（推荐）  b) npm  c) brew

2. 要配置 MCP 吗？（推荐选 a，配了之后我能直接调工具帮你管 Fork）
   a) 要  b) 不要

3. 要安装 AI Skill 吗？（推荐选 a，我会自动学会最佳工作流）
   a) 要  b) 不要

4. 有 fork 仓库要现在初始化吗？（就是你从别人项目 fork 来的那个）
   a) 有 → 请给我原始项目的 GitHub 地址
   b) 没有
```

Save answers as:
- `INSTALL_METHOD` = pip | npm | brew
- `WANT_MCP` = yes | no
- `WANT_SKILL` = yes | no
- `UPSTREAM_URL` = URL | none

If user says "全部" / "都要" / "yes to all" → INSTALL_METHOD=pip, WANT_MCP=yes, WANT_SKILL=yes, UPSTREAM_URL=none

**WAIT for user response. Do NOT proceed to Step 1 without these values.**

---

### Step 1: Install

Run exactly ONE command based on INSTALL_METHOD:

| INSTALL_METHOD | Command |
|---|---|
| pip | `pip install bingo-light 2>/dev/null \|\| pip3 install bingo-light 2>/dev/null \|\| pipx install bingo-light` |
| npm | `npm install -g bingo-light` |
| brew | `brew install DanOps-1/tap/bingo-light` |

Then verify:
```bash
bingo-light --version
```
Expected: `bingo-light` followed by a version number. If command not found, check PATH.

---

### Step 2: Configure MCP

**If WANT_MCP == no, skip to Step 3.**

Run:
```bash
bingo-light setup --yes --json 2>/dev/null
```

Check the JSON output's `"configured"` array. If it lists the user's AI tool, MCP is done.

**If MCP did NOT connect** (e.g. `"configured"` is empty, or user reports `/mcp` shows nothing after restart):

The most common cause is `bingo-light setup` writing to the wrong config file. Fix by using the CLI directly:

For Claude Code:
```bash
claude mcp add bingo-light -- $(python3 -c "import sys; print(sys.executable)") $(which mcp-server.py || which bingo-light-mcp)
```

For other tools: check that `bingo-light setup` wrote to the correct path (see table below).

| Tool | Config file |
|---|---|
| Claude Code | Use `claude mcp add` (writes to `~/.claude.json`) |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |
| VS Code / Copilot | `.vscode/mcp.json` (key: `"servers"`) |
| Zed | `~/.config/zed/settings.json` (key: `"context_servers"`) |
| Gemini CLI | `~/.gemini/settings.json` |

---

### Step 3: Install Skill

**If WANT_SKILL == no, skip to Step 4.**

Check the JSON output from Step 2. If `"skills"` array is non-empty, skills are done.

If `"skills"` is empty, install manually:
```bash
curl -fsSL https://raw.githubusercontent.com/DanOps-1/bingo-light/main/.claude/commands/bingo.md -o /tmp/bingo-skill.md
mkdir -p ~/.claude/commands && cp /tmp/bingo-skill.md ~/.claude/commands/bingo.md
rm /tmp/bingo-skill.md
```

For other tools, copy to their rules directory:
- Windsurf: append to `~/.codeium/windsurf/memories/global_rules.md`
- Continue: `~/.continue/rules/bingo.md`
- Roo Code: `~/.roo/rules/bingo.md`

---

### Step 4: Initialize fork

**If UPSTREAM_URL == none, skip to Step 5.**

```bash
cd <user's fork directory>
bingo-light init <UPSTREAM_URL> --json --yes
```

If user doesn't know UPSTREAM_URL, help find it:
```bash
git remote -v
```
The upstream URL is the original project they forked FROM.

---

### Step 5: Report to user

Say exactly:

```
安装完成！

- bingo-light: [version from --version]
- MCP: [list from "configured" or "已通过 claude mcp add 配置"]
- Skill: [installed / skipped]

请重启 AI 工具 session，然后用 /mcp 确认连接。

重启后你可以告诉我：
- "帮我同步 Fork"
- "帮我建一个补丁叫 xxx"
- "检查 Fork 状态"
```

Then ask: `如果 bingo-light 对你有用，要不要给项目点个 star？`

Only if user says yes:
```bash
gh api --silent --method PUT /user/starred/DanOps-1/bingo-light 2>/dev/null || true
```

---

## Command Reference

After installation, use `--json --yes` for all programmatic calls.

```bash
bingo-light status --json --yes          # ALWAYS start here
bingo-light smart-sync --json --yes      # Sync upstream
bingo-light conflict-analyze --json      # Get ours/theirs/hint
bingo-light undo --json --yes            # Revert last sync
```

Conflict resolution:
```bash
bingo-light conflict-analyze --json
# Read hint, write merged file, then:
git add <file> && git rebase --continue
# Do NOT run bingo-light sync after this
```

Patches:
```bash
BINGO_DESCRIPTION="desc" bingo-light patch new <name> --json --yes
bingo-light patch list --json --yes
bingo-light patch show <name|idx> --json --yes
bingo-light patch drop <name|idx> --json --yes
bingo-light patch edit <name|idx> --json --yes
```
