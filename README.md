```
        _                         _ _       _     _
  _ __ (_)_ __   __ _  ___       | (_) __ _| |__ | |_
 | '_ \| | '_ \ / _` |/ _ \ ____| | |/ _` | '_ \| __|
 | |_) | | | | | (_| | (_) |____| | | (_| | | | | |_
 | .__/|_|_| |_|\__, |\___/     |_|_|\__, |_| |_|\__|
 |_|            |___/                 |___/
```

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Made_with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)](.github/workflows)
[![Version](https://img.shields.io/badge/Version-0.1.0-orange.svg)](pingo-light)

**Dead-simple fork maintenance. One file, one command, zero drama.**

**让 Fork 维护变得无痛 —— 一个文件，一条命令，告别合并冲突的噩梦。**

---

## :dart: The Problem

You fork an open-source project, add a few custom features, and life is good — until upstream pushes 200 commits and your `git rebase` turns into a three-hour conflict resolution marathon. Your customizations get scattered, lost, or mangled. Next quarter, you dread syncing again.

pingo-light eliminates this entirely. Your changes stay organized as a clean, named patch stack that rebases onto upstream in a single command. Conflict resolutions are remembered automatically, so you only solve each conflict once, ever.

## :tv: See It In Action

```
$ cd my-forked-project
$ pingo-light init https://github.com/original/project.git

> Adding 'upstream' remote...
> Fetching upstream...
> Auto-detected upstream branch: main
> Enabling git rerere (auto-remembers conflict resolutions)...
> Creating tracking branch 'upstream-tracking'...
OK pingo-light initialized!

  Upstream : https://github.com/original/project.git (main)
  Tracking : upstream-tracking (mirrors upstream, don't touch)
  Patches  : pingo-patches (your customizations go here)
```

```
$ vim src/theme.py
$ pingo-light patch new dark-mode

> Staging all changes...
> Description (optional): support dark color scheme
OK Patch 'dark-mode' created.

$ pingo-light patch list

  # │ Patch       │ Hash    │ Changes
  1 │ dark-mode   │ a3f7c21 │ +84 -12 (3 files)
```

```
$ pingo-light sync

> Fetching upstream...
> Upstream has 47 new commits.
> Updating tracking branch...
> Rebasing 1 patch onto new upstream...
OK Sync complete. All patches applied cleanly.
```

## :sparkles: Feature Highlights

- **Single file, zero dependencies** — just bash + git. Drop it in your PATH and go.
- **Named patch stack** — each customization is one atomic, named commit. List, show, edit, reorder, drop.
- **One-command sync** — `pingo-light sync` fetches upstream and rebases your entire patch stack.
- **Dry-run sync** — `sync --dry-run` tests on a temporary branch without touching anything.
- **Conflict memory** — git rerere is auto-enabled; resolve a conflict once, never again.
- **Undo** — `pingo-light undo` restores your patches branch to its pre-sync state.
- **Conflict prediction** — `pingo-light status` warns about files that both you and upstream changed.
- **Doctor** — `pingo-light doctor` runs a full diagnostic with a test rebase.
- **Export / Import** — share patches as `.patch` files (quilt-compatible `series` file included).
- **Auto-sync CI** — `pingo-light auto-sync` generates a GitHub Actions workflow with conflict alerting.
- **MCP server** — LLM integration via 13 MCP tools; zero-dep Python, works with Claude Code out of the box.

## :package: Quick Install

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/user/pingo-light/main/pingo-light -o /usr/local/bin/pingo-light && chmod +x /usr/local/bin/pingo-light
```

**From source:**

```bash
git clone https://github.com/user/pingo-light.git
cd pingo-light
./install.sh            # installs to /usr/local/bin (uses sudo if needed)
```

**Manual:**

```bash
cp pingo-light /usr/local/bin/pingo-light
chmod +x /usr/local/bin/pingo-light
```

## :rocket: Quick Start

1. **Fork and clone** an open-source project as usual.
2. **Initialize** pingo-light inside your clone:
   ```bash
   pingo-light init https://github.com/original/project.git
   ```
3. **Make changes** to the code — add features, fix bugs, anything.
4. **Create a patch** for each logical change:
   ```bash
   pingo-light patch new my-feature
   ```
5. **Sync with upstream** whenever you want:
   ```bash
   pingo-light sync
   ```
6. **Check health** at any time:
   ```bash
   pingo-light status
   ```

## :book: Command Reference

| Command | Description |
|---|---|
| `init <upstream-url> [branch]` | Initialize pingo-light, set up upstream tracking and patch branch |
| `patch new <name>` | Create a new named patch from current changes |
| `patch list [-v]` | List all patches in the stack with stats |
| `patch show <name\|index>` | Show full diff for a specific patch |
| `patch edit <name\|index>` | Amend an existing patch (stage fixes first) |
| `patch drop <name\|index>` | Remove a patch from the stack |
| `patch reorder` | Interactively reorder, squash, or drop patches |
| `patch export [dir]` | Export patches as `.patch` files with series file |
| `patch import <file\|dir>` | Import `.patch` files into the stack |
| `sync [--dry-run] [--force]` | Fetch upstream and rebase all patches |
| `undo` | Revert patches branch to pre-sync state |
| `status` | Health check: drift, patches, conflict prediction |
| `doctor` | Full diagnostic with test rebase |
| `diff` | Combined diff of all patches vs upstream |
| `log` | Show sync history (tracking branch reflog) |
| `auto-sync` | Generate GitHub Actions workflow for automated syncing |
| `version` | Print version |
| `help` | Print usage summary |

## :gear: How It Works

```
  upstream (github.com/original/project)
      |
      |  git fetch
      v
  upstream-tracking -------- exact mirror, never touched manually
      |
      |  rebase
      v
  pingo-patches ------------ your customizations live here
      |
      +-- [pl] dark-mode:     support dark color scheme
      +-- [pl] api-cache:     add Redis caching layer
      +-- [pl] fix-typo:      fix README typo
      |
      v
    HEAD (your working fork)
```

**Sync flow:** `fetch upstream` -> `fast-forward upstream-tracking` -> `rebase pingo-patches onto upstream-tracking`. Your patches always sit cleanly on top. Rerere remembers every conflict resolution automatically.

**Config** is stored in `.pingolight` (git-config format) and excluded from version control via `.git/info/exclude` — zero noise in your repo.

## :balance_scale: Comparison

| | pingo-light | Manual rebase | quilt | patch-package | StGit |
|---|:---:|:---:|:---:|:---:|:---:|
| Zero dependencies | **Yes** | Yes | No (quilt) | No (Node.js) | No (Python) |
| Single file | **Yes** | N/A | No | No | No |
| Named patches | **Yes** | No | Yes | Yes | Yes |
| One-command sync | **Yes** | No | No | No | Yes |
| Dry-run sync | **Yes** | No | No | No | No |
| Conflict memory | **Yes** (rerere) | Manual | No | No | No |
| Conflict prediction | **Yes** | No | No | No | No |
| CI auto-sync | **Built-in** | DIY | No | No | No |
| LLM / MCP integration | **Built-in** | No | No | No | No |
| Works on any git repo | **Yes** | Yes | Partial | npm only | Yes |
| Learning curve | **Minutes** | Hours | Hours | Minutes | Hours |

## :robot: MCP Integration

pingo-light ships with an MCP server (`mcp-server.py`) that exposes all commands as tools for LLM clients. Zero-dep Python 3, works over stdio.

**Claude Code** — add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "pingo-light": {
      "command": "python3",
      "args": ["/path/to/pingo-light/mcp-server.py"]
    }
  }
}
```

**Available tools:** `pingo_init`, `pingo_status`, `pingo_sync`, `pingo_undo`, `pingo_patch_new`, `pingo_patch_list`, `pingo_patch_show`, `pingo_patch_drop`, `pingo_patch_export`, `pingo_patch_import`, `pingo_doctor`, `pingo_diff`, `pingo_auto_sync`

All tools accept a `cwd` parameter pointing to your git repo. The server also works with Claude Desktop, VS Code Copilot, Cursor, and any MCP-compatible client.

## :handshake: Contributing

Contributions are welcome! Please open an issue or submit a pull request.

The entire tool is a single bash script (`pingo-light`, ~1300 lines). No build step — edit and test directly.

```bash
# Quick test setup
mkdir /tmp/test-upstream && cd /tmp/test-upstream && git init && echo "hello" > file.txt && git add -A && git commit -m "init"
git clone /tmp/test-upstream /tmp/test-fork && cd /tmp/test-fork
pingo-light init /tmp/test-upstream
```

## :scroll: License

[MIT](LICENSE) — use it, fork it, patch it (with pingo-light, of course).

---

<details>
<summary><b>简体中文</b></summary>

## pingo-light — 让 Fork 维护变得无痛

### 问题

当你 Fork 了一个开源项目并添加了自定义功能，与上游同步就变成了一场噩梦：合并冲突、丢失的修改、数小时的手动排查。

### 解决方案

pingo-light 将你的自定义改动组织为一个干净的补丁栈，建立在上游代码之上。同步只需一条命令，冲突解决方案会被自动记忆。

### 核心特性

- **单文件，零依赖** — 只需 bash + git
- **命名补丁栈** — 每个自定义修改都是一个独立的、命名的补丁
- **一键同步** — `pingo-light sync` 获取上游更新并变基所有补丁
- **冲突预测** — `pingo-light status` 提前警告潜在冲突
- **冲突记忆** — git rerere 自动记住冲突解决方案，同样的冲突只需解决一次
- **MCP 集成** — 内置 MCP 服务器，支持 Claude Code 等 LLM 工具直接调用

### 快速开始

```bash
# 安装
curl -fsSL https://raw.githubusercontent.com/user/pingo-light/main/pingo-light -o /usr/local/bin/pingo-light && chmod +x /usr/local/bin/pingo-light

# 初始化
cd my-forked-project
pingo-light init https://github.com/original/project.git

# 创建补丁
vim src/feature.py
pingo-light patch new my-feature

# 与上游同步
pingo-light sync
```

</details>
