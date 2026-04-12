# bingo-light Python Core Rewrite

> **For agentic workers:** This spec describes a complete rewrite of bingo-light from Bash to Python. The Bash script is archived; the Python version becomes the sole implementation.

**Goal:** Eliminate the entire class of Bash+pipefail bugs by rewriting core logic in Python, keeping the same CLI interface and passing all 178 existing tests.

**Decision log:**
- Architecture: Python core + Python CLI (option C)
- Dependencies: Pure stdlib, zero pip install (option A)
- File split: Two files — `bingo_core.py` + `bingo-light` (option A)
- Migration: One-shot rewrite, old Bash archived (option A)

---

## Architecture

```
bingo-light          Python CLI entry (~300 lines)
bingo_core.py        Core library (~1500 lines)
mcp-server.py        MCP server — import bingo_core directly
agent.py             Advisor agent — import bingo_core directly
tui.py               TUI dashboard — import bingo_core directly
```

### Key principle

Every command returns a Python `dict`. The CLI entry decides output format:
- `--json` → `json.dumps(result)`
- default → human-readable colored text

No function ever builds JSON strings manually. `json.dumps()` handles all escaping.

### Dependency chain

```
bingo-light (CLI) ──import──→ bingo_core
mcp-server.py     ──import──→ bingo_core
agent.py           ──import──→ bingo_core
tui.py             ──import──→ bingo_core
```

MCP server calls Python functions directly — zero subprocess overhead, zero JSON parsing.

---

## `bingo_core.py` — Class Design

### `Git` — Unified git subprocess wrapper

```python
class Git:
    def __init__(self, cwd: str): ...
    def run(self, *args, check=True, capture=True) -> str
    def rev_parse(self, ref: str) -> str | None      # None if ref missing
    def rev_list_count(self, range_spec: str) -> int  # 0 if invalid
    def fetch(self, remote: str) -> bool
    def rebase(self, onto, upstream, branch) -> tuple[bool, str]
    def ls_files_unmerged(self) -> list[str]
    def diff_names(self, range_spec: str) -> list[str]
    def log_patches(self, base: str, branch: str) -> list[PatchInfo]
```

All git errors become Python exceptions (`GitError`). No silent failures, no pipefail crashes. Each method has a defined return type — no "might be empty string, might be multiline, might crash."

### `Config` — `.bingolight` management

```python
@dataclass
class Config:
    upstream_url: str
    upstream_branch: str
    patches_branch: str = "bingo-patches"
    tracking_branch: str = "upstream-tracking"

    @classmethod
    def load(cls, git: Git) -> "Config"       # git config --file .bingolight
    def save(self, git: Git) -> None
    def get(self, key: str) -> str | None      # arbitrary keys (test.command etc.)
    def set(self, key: str, value: str) -> None
    def list_all(self) -> dict[str, str]
```

Uses `git config --file .bingolight` under the hood — same format as Bash version, fully compatible.

### `State` — `.bingo/` directory state

```python
class State:
    def __init__(self, bingo_dir: Path): ...

    # Undo
    def save_undo(self, head: str, tracking: str) -> None
    def load_undo(self) -> tuple[str, str] | None
    def set_undo_active(self) -> None
    def clear_undo_active(self) -> None
    def is_undo_active(self) -> bool

    # Circuit breaker
    def record_sync_failure(self, upstream_target: str) -> None
    def check_circuit_breaker(self, upstream_target: str) -> bool  # True = blocked
    def clear_sync_failures(self) -> None

    # Metadata
    def get_patch_meta(self, name: str) -> dict
    def set_patch_meta(self, name: str, key: str, value: str) -> None

    # Sync history
    def record_sync(self, entry: dict) -> None
    def get_history(self) -> list[dict]

    # Session
    def update_session(self, content: str) -> None
    def get_session(self) -> str | None

    # Hooks
    def run_hooks(self, event: str, data: dict) -> None
```

### `Repo` — Top-level facade

```python
class Repo:
    git: Git
    config: Config
    state: State

    def __init__(self, cwd: str = "."): ...

    # Status & diagnostics
    def status(self) -> dict                    # recommended_action, behind, patches, etc.
    def doctor(self) -> dict                    # health checks
    def diff(self) -> dict                      # all changes vs upstream
    def history(self) -> dict                   # sync history
    def session(self, update: bool = False) -> dict

    # Sync
    def sync(self, dry_run=False, force=False, test=False) -> dict
    def smart_sync(self) -> dict
    def undo(self) -> dict

    # Patches
    def patch_new(self, name: str, description: str = "") -> dict
    def patch_list(self, verbose: bool = False) -> dict
    def patch_show(self, target: str) -> dict
    def patch_edit(self, target: str) -> dict
    def patch_drop(self, target: str) -> dict
    def patch_export(self, output_dir: str = ".") -> dict
    def patch_import(self, path: str) -> dict
    def patch_reorder(self, order: str = "") -> dict
    def patch_squash(self, idx1: int, idx2: int) -> dict
    def patch_meta(self, target: str, key: str = "", value: str = "") -> dict

    # Config
    def config_get(self, key: str) -> dict
    def config_set(self, key: str, value: str) -> dict
    def config_list(self) -> dict

    # Conflict
    def conflict_analyze(self) -> dict

    # Other
    def init(self, upstream_url: str, branch: str = "") -> dict
    def test(self) -> dict
    def auto_sync(self) -> dict
    def workspace_init(self) -> dict
    def workspace_add(self, path: str) -> dict
    def workspace_list(self) -> dict
    def workspace_sync(self) -> dict
```

Every method returns `dict` with `{"ok": True, ...}` or raises `BingoError`.

### Data classes

```python
@dataclass
class PatchInfo:
    name: str
    hash: str
    subject: str
    files: int
    stat: str = ""

@dataclass
class ConflictInfo:
    file: str
    ours: str
    theirs: str
    conflict_count: int
    merge_hint: str
```

### Exceptions

```python
class BingoError(Exception):
    """All bingo-light errors. CLI catches this and formats as JSON or human text."""
    pass

class GitError(BingoError):
    """Git command failed."""
    def __init__(self, cmd: list[str], returncode: int, stderr: str): ...

class NotInitializedError(BingoError): ...
class DirtyTreeError(BingoError): ...
class NotGitRepoError(BingoError): ...
```

---

## `bingo-light` — CLI Entry

```python
#!/usr/bin/env python3
"""bingo-light — AI-native fork maintenance tool"""

import sys, json, argparse
from bingo_core import Repo, BingoError

VERSION = "2.0.0"

def main():
    parser = argparse.ArgumentParser(prog="bingo-light", description="AI-native fork maintenance tool")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--yes", "-y", action="store_true", help="Non-interactive mode")
    parser.add_argument("--version", action="version", version=f"bingo-light {VERSION}")
    subparsers = parser.add_subparsers(dest="command")

    # Register all commands as subparsers...
    # e.g. subparsers.add_parser("status")
    # e.g. p = subparsers.add_parser("sync"); p.add_argument("--dry-run", ...)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(0)

    try:
        repo = Repo(".")
        result = dispatch(repo, args)
        output(result, args.json)
    except BingoError as e:
        output({"ok": False, "error": str(e)}, args.json)
        sys.exit(1)

def output(result: dict, json_mode: bool):
    if json_mode:
        print(json.dumps(result, ensure_ascii=False))
    else:
        format_human(result)

def format_human(result: dict):
    """Convert result dict to colored terminal output."""
    # Uses ANSI escape codes, suppressed if not a TTY
    ...
```

### Human output formatting

Each command type gets a formatter function:

```python
FORMATTERS = {
    "status": format_status,      # Show upstream info, patches, conflict risk
    "patch_list": format_patches,  # Numbered patch list with stats
    "sync": format_sync,          # Sync result or conflict details
    "error": format_error,        # Red error message
    ...
}
```

Colors use raw ANSI codes (no dependencies). Auto-detect TTY — no colors when piped.

---

## MCP Server Changes

```python
# Before (subprocess):
def handle_tool_call(name, arguments):
    if name == "bingo_status":
        result = run_bl(["status"], cwd)  # subprocess + JSON parse
        return {"content": [{"type": "text", "text": result.stdout}]}

# After (direct import):
from bingo_core import Repo

def handle_tool_call(name, arguments):
    cwd = arguments.get("cwd", ".")
    repo = Repo(cwd)
    if name == "bingo_status":
        result = repo.status()  # direct Python call
        return {"content": [{"type": "text", "text": json.dumps(result)}]}
```

### Security retained
- Path traversal check in `bingo_conflict_resolve` stays (`.git/` block, `relative_to()` check)
- Content-Length bounds stay in `read_message()`
- `cwd` validation stays

### Removed
- `run_bl()` function (no more subprocess)
- `--json --yes` auto-append logic
- Timeout handling (no subprocess to timeout)

---

## Compatibility

### CLI interface: 100% backward compatible
- Same commands, same flags, same output format
- `bingo-light status --json --yes` produces identical JSON
- All existing tests pass without modification

### Config: 100% compatible
- `.bingolight` format unchanged (git config)
- `.bingo/` directory structure unchanged
- Repos initialized with Bash version work with Python version and vice versa

### MCP: protocol compatible, implementation changes
- Same 29 tools, same JSON-RPC interface
- Clients see no difference
- Internal: direct import instead of subprocess

### Version bump
- Bash version: 1.2.0 (archived as `bingo-light.bash`)
- Python version: 2.0.0

---

## Testing

### Existing tests (178) — all must pass
- `tests/test.sh` — core functional (70 tests)
- `tests/test-json.sh` — JSON fuzz (55 tests)
- `tests/test-edge.sh` — git boundary (18 tests)
- `tests/test-mcp.py` — MCP protocol (35 tests)

Tests call `bingo-light` as a subprocess, so they test the CLI interface, not internals. The Python rewrite must produce identical output.

### New tests
- `tests/test_core.py` — Python unit tests for `bingo_core` classes
- Direct function calls, no subprocess overhead
- Cover edge cases that shell tests can't easily test (e.g., exception handling, type safety)

---

## What Gets Eliminated

| Bash problem | Lines affected | Python solution |
|---|---|---|
| `set -euo pipefail` crashes | 28+ locations | Python exceptions |
| `json_escape()` bugs | 41 call sites | `json.dumps()` |
| Manual JSON string building | 62 `json_out` calls | `return dict` |
| Pipe exit code propagation | 300 pipes | `subprocess.run(check=True)` |
| Variable type confusion | Entire script | Type hints + dataclasses |
| Silent failures via `\|\| true` | 20+ locations | Explicit try/except |
| Shell portability (GNU vs BSD) | sed, awk, wc, find | Python stdlib |
| State race conditions | tracking/patches/undo | Class invariants |

---

## Files Changed

| File | Action |
|---|---|
| `bingo_core.py` | **NEW** — core library (~1500 lines) |
| `bingo-light` | **REWRITE** — Python CLI entry (~300 lines) |
| `mcp-server.py` | **MODIFY** — import bingo_core, remove subprocess |
| `agent.py` | **MODIFY** — import bingo_core, remove run_bl subprocess |
| `tui.py` | **MODIFY** — import bingo_core, remove subprocess |
| `bingo-light.bash` | **NEW** — archived copy of old Bash version |
| `tests/test_core.py` | **NEW** — Python unit tests |
| `CLAUDE.md` | **UPDATE** — new architecture docs |
| `completions/*` | **KEEP** — unchanged (same CLI interface) |
