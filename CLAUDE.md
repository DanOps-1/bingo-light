# pingo-light

Bash CLI tool for maintaining forks of open-source projects. Single file, zero dependencies beyond git + bash.

## Project structure

- `pingo-light` — The entire tool (single executable bash script, ~1300 lines)
- `mcp-server.py` — MCP tool server (zero-dep Python, wraps CLI as 13 MCP tools)
- `install.sh` — Copies pingo-light to /usr/local/bin
- `llms.txt` — Complete reference documentation for LLM consumption

## How it works

User's customizations are maintained as a linear stack of git commits (patches) on a `pingo-patches` branch, rebased on top of an `upstream-tracking` branch that mirrors the upstream project. Each patch commit has the prefix `[pl] <name>:`. Syncing fetches upstream and rebases the patch stack. git rerere auto-remembers conflict resolutions.

## MCP Server

The MCP server exposes all pingo-light commands as tools that any MCP-compatible LLM can call directly. Pure Python 3 stdlib, no pip install needed.

### Setup for Claude Code

Add to `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "pingo-light": {
      "command": "python3",
      "args": ["/home/kali/pingo-light/mcp-server.py"]
    }
  }
}
```

### Available MCP Tools

| Tool | Maps to |
|------|---------|
| `pingo_init` | `pingo-light init <url> [branch]` |
| `pingo_status` | `pingo-light status` |
| `pingo_sync` | `pingo-light sync [--dry-run] [--force]` |
| `pingo_undo` | `pingo-light undo` |
| `pingo_patch_new` | `pingo-light patch new <name>` |
| `pingo_patch_list` | `pingo-light patch list [-v]` |
| `pingo_patch_show` | `pingo-light patch show <target>` |
| `pingo_patch_drop` | `pingo-light patch drop <target>` |
| `pingo_patch_export` | `pingo-light patch export [dir]` |
| `pingo_patch_import` | `pingo-light patch import <path>` |
| `pingo_doctor` | `pingo-light doctor` |
| `pingo_diff` | `pingo-light diff` |
| `pingo_auto_sync` | `pingo-light auto-sync` |

All tools require `cwd` parameter (path to the git repo).

## Development

No build step. Edit `pingo-light` directly. Test by running it in a git repo.

Quick test setup:
```bash
mkdir /tmp/test-upstream && cd /tmp/test-upstream && git init && echo "hello" > file.txt && git add -A && git commit -m "init"
git clone /tmp/test-upstream /tmp/test-fork && cd /tmp/test-fork
pingo-light init /tmp/test-upstream
```

## Key internals

- Config: `.pingolight` file (git-config format) with section `[pingolight]`
- Patch identification: commit messages matching `[pl] <name>: <desc>`
- Dry-run sync: creates temp branches `pl-dryrun-$$`, cleaned up after
- Doctor test: creates temp branch `pl-doctor-$$`, cleaned up after
- Patch resolution: by name (exact -> partial match) or 1-based index
- MCP server: JSON-RPC 2.0 over stdio, disables color (NO_COLOR=1) for machine output
