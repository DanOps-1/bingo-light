# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

bingo-light is an AI-native fork maintenance tool. It manages customizations as a clean patch stack on top of upstream, with `--json` and `--yes` flags for AI agent consumption. Python CLI (`bingo-light` + `bingo_core.py`) + MCP server (Python 3, 29 tools).

## Commands

```bash
make test          # run core test suite (tests/test.sh)
make lint          # python syntax + flake8 + shellcheck
make test-all      # all 250 tests (core + fuzz + edge + MCP + unit)

# Full test pipeline (250 tests across 5 suites):
./tests/run-all.sh              # all suites + coverage report
./tests/test.sh                 # core functional tests
./tests/test-json.sh            # JSON fuzz with dangerous inputs
./tests/test-edge.sh            # git state boundary tests
python3 ./tests/test-mcp.py     # MCP protocol tests
python3 ./tests/test_core.py    # Python unit tests

# Syntax check without running:
python3 -c "import py_compile; py_compile.compile('bingo-light', doraise=True)"
python3 -c "import py_compile; py_compile.compile('bingo_core.py', doraise=True)"
python3 -c "import py_compile; py_compile.compile('mcp-server.py', doraise=True)"
```

## Architecture

**bingo-light** (Python 3) — CLI entry point. Delegates all business logic to `bingo_core.Repo`. Handles argparse, human-readable formatting, and exit codes. Every command has two output paths: human-readable (default) and JSON (`--json` flag).

**bingo_core.py** (Python 3) — Core library. All business logic: sync, patches, conflict analysis, workspace, doctor, etc. Config stored in `.bingolight` via `git config --file`. Uses `.bingo/.lock` for concurrency protection.

**mcp-server.py** (Python 3, stdlib only) — Thin MCP wrapper over the CLI. Calls `run_bl()` which spawns `bingo-light --json --yes` as a subprocess. Adds `--json --yes` to ALL commands automatically. Has `try/except` around `handle_tool_call()` to prevent crashes from bad input. Uses Content-Length framed JSON-RPC 2.0 over stdio.

**agent.py** — Advisor agent. Observe → Analyze → Safe-act or Report. LLM is used for analysis ONLY, never code execution. Can run without API key (graceful degradation).

**tui.py** — Curses dashboard. Read-only status viewer with sync/dry-run.

## Critical patterns to follow when editing

**Return dicts, not prints**: Every `Repo` method returns a dict with `ok` key. The CLI formats it for human output. Never `print()` from `bingo_core.py`.

**Git subprocess safety**: All `git` calls go through `Git.run()` / `Git.run_ok()` / `Git.run_unchecked()`. Never use `subprocess.run(["git", ...])` directly except in rebase continue paths (which need custom env).

**Concurrency**: Destructive operations (sync, smart_sync) must use `self.state.acquire_lock()` / `release_lock()` in a try/finally.

**Config security**: `.bingolight` must NOT be tracked by git. `_load()` checks this and rejects tracked configs (upstream injection risk). `test.command` runs via `bash -c` — the value comes from config, so this is a trust boundary.

**Conflict detection**: Use `git ls-files --unmerged | cut -f2 | sort -u`, NOT `git diff --name-only --diff-filter=U` (misses delete/modify and rename conflicts).

**Undo state**: sync saves `.bingo/.undo-head` + `.bingo/.undo-tracking`. Undo writes `.bingo/.undo-active` to prevent `_fix_stale_tracking()` from auto-advancing tracking. Sync clears `.undo-active`.

## Key internals

- Config: `.bingolight` (git-config format), excluded via `.git/info/exclude`
- Patch ID: commit messages matching `[bl] <name>: <desc>`
- Patch names: validated to `^[a-zA-Z0-9][a-zA-Z0-9_-]*$`
- Branches: `upstream-tracking` (mirror), `bingo-patches` (patches on top)
- MCP server version must match CLI VERSION (currently 2.0.0)
- `_fix_stale_tracking()`: auto-repairs tracking branch after manual conflict resolution, skipped if `.bingo/.undo-active` exists or rebase is in progress

## When adding a new command

1. Add the method in `bingo_core.py` (in `Repo` class)
2. Return a dict with `ok` key
3. Add dispatch in `bingo-light` CLI (argparse + dispatch function)
4. Add human-readable formatter in `bingo-light` if needed
5. Add to all 3 shell completions (`completions/*.bash`, `.zsh`, `.fish`)
6. Add to `llms.txt` command reference
7. Update README.md and README.zh-CN.md if user-facing

## When adding a new MCP tool

1. Add tool definition to `TOOLS` array in `mcp-server.py`
2. Add handler in `handle_tool_call()`
3. `run_bl()` auto-adds `--json --yes` — don't add them manually
4. Update MCP tool tables in README.md, README.zh-CN.md, CLAUDE.md
5. Update badge count if it changed

## For AI agents: prefer MCP or --json

```bash
bingo-light status --json
bingo-light sync --json --yes
bingo-light conflict-analyze --json
BINGO_DESCRIPTION="add feature X" bingo-light patch new feature-x --yes
```
