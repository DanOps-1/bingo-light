# Comprehensive Improvements Design Spec

Date: 2026-04-12

## Overview

11 improvements spanning quick fixes, new features, UX polish, and architecture refactoring. Ordered by dependency — architecture changes first (they reshape file layout), then features, then polish.

---

## Phase 1: Architecture Refactoring

### 1.1 Split bingo_core.py into package (Item #6)

Split the 2,838-line monolith into a `bingo_core/` package with 6 modules:

```
bingo_core/
  __init__.py      # Re-export: Repo, Git, Config, State, PatchInfo, ConflictInfo, all exceptions
  exceptions.py    # BingoError, GitError, NotGitRepoError, NotInitializedError, DirtyTreeError
  models.py        # PatchInfo, ConflictInfo dataclasses
  git.py           # Git class (subprocess wrapper)
  config.py        # Config class (.bingolight reader/writer)
  state.py         # State class (metadata, sync history, locks, undo, circuit breaker)
  repo.py          # Repo class (all business logic) — imports from all above
```

**Constraints:**
- `__init__.py` re-exports everything that `from bingo_core import X` currently provides — zero breakage for CLI, MCP server, tests
- Constants (`PATCH_PREFIX`, `DEFAULT_PATCHES`, `DEFAULT_TRACKING`, `MAX_RESOLVE_ITER`, `VERSION`) go in `__init__.py`
- Delete old `bingo_core.py` after migration
- `py_compile` check on every module

### 1.2 MCP server direct import (Item #5)

Replace subprocess-per-call with direct Python import:

```python
# Before (mcp-server.py)
def run_bl(args): subprocess.run(["bingo-light", "--json", "--yes"] + args)

# After
from bingo_core import Repo
repo = Repo(cwd)
result = repo.status()  # direct call, returns dict
```

**Constraints:**
- Keep `mcp-server.py` as a single file (no additional dependencies)
- Each tool handler calls the appropriate `Repo` method directly
- Error handling: wrap in try/except, return `{"ok": false, "error": str(e)}`
- `cwd` parameter per MCP call (already exists in tool input schema)
- Remove `run_bl()` function entirely
- MCP server still uses stdin/stdout JSON-RPC framing (unchanged)

### 1.3 Deduplicate conflict handling (Item #7)

Extract shared conflict-building logic from `sync()` and `smart_sync()`:

```python
# In repo.py
def _build_conflict_result(self, c: dict, conflicted_files: list,
                           saved_tracking: str = "") -> dict:
    """Build standardized conflict result dict."""
    conflicts = [self._extract_conflict(f) for f in conflicted_files]
    current_patch = self._current_rebase_patch()
    return {
        "ok": False,
        "conflict": True,
        "current_patch": current_patch,
        "conflicted_files": conflicted_files,
        "conflicts": [c_.to_dict() for c_ in conflicts],
        "resolution_steps": [...],
        "abort_cmd": "git rebase --abort",
        ...
    }
```

Both `sync()` and `_smart_sync_locked()` call this instead of building their own dicts. Also extract `_current_rebase_patch()` helper.

---

## Phase 2: New Features

### 2.1 conflict-resolve command (Item #1)

**CLI interface:**
```bash
bingo-light conflict-resolve <file> [--content-stdin] [--yes]
```

The file content is provided via stdin (AI-friendly) or the user edits the file manually before running the command.

**Behavior:**
1. Verify rebase is in progress, file is in unmerged state
2. If `--content-stdin`: read content from stdin, write to file
3. `git add <file>`
4. Check if more unmerged files remain — if yes, return conflict-analyze result for next file
5. If no more unmerged files: `git rebase --continue`
6. If rebase --continue triggers new conflicts (next patch): return conflict-analyze for new conflicts
7. If rebase completes: return sync-complete result

**Return dict:**
```python
# Still have conflicts in current patch:
{"ok": True, "resolved": "app.py", "remaining": ["config.yaml"],
 "conflicts": [...]}  # analyze data for next file

# Current patch done, but next patch conflicts:
{"ok": True, "resolved": "app.py", "rebase_continued": True,
 "conflict": True, "conflicted_files": [...], "conflicts": [...]}

# All done:
{"ok": True, "resolved": "app.py", "rebase_continued": True,
 "sync_complete": True, "patches_rebased": 3}
```

**Human formatter:** Shows what was resolved, what's next, or success message.

**Core method:** `Repo.conflict_resolve(file: str, content: str = "") -> dict`

### 2.2 workspace remove command (Item #9)

```bash
bingo-light workspace remove <alias|path> [--yes]
```

Removes a repo entry from `.bingo-workspace.json`. Does not delete the actual directory. Returns `{"ok": True, "removed": "<alias>"}`.

---

## Phase 3: UX Improvements

### 3.1 Differentiate log vs history (Item #2)

- `log` — compact one-line-per-sync view (current format after our fix)
- `history` — verbose view with per-patch hash mappings

```
# bingo-light log
  2026-04-12T12:24:31Z  1 commit(s) integrated  efa4419 → e025bcd  (4 patch(es) rebased)

# bingo-light history
  Sync @ 2026-04-12T12:24:31Z
    Upstream: efa4419 → e025bcd (1 commit)
    Patches rebased:
      healthcheck-instance  a44010d → 0b97128
      staging-db            7315527 → 0439a38
      strict-auth           188f822 → 070fe6e
      rate-limiter          ecfe6a1 → 7ee677a
```

Implementation: `log` calls `repo.history()` and uses `_format_log` (compact). `history` calls `repo.history()` and uses `_format_history` (verbose). The data source is the same, only formatting differs.

### 3.2 Fix patch meta tags single-key repr (Item #3)

In `_format_patch_meta`, the get-single-key branch returns raw `result["value"]` which is a Python list for tags. Fix:

```python
# In get-single-key branch:
v = result.get("value", "")
if isinstance(v, list):
    v = ", ".join(v) if v else "(none)"
return f"  {k}: {v}"
```

### 3.3 Update shell completions (Item #4)

Add missing commands/subcommands to all three completion files:

**Missing in all three:**
- `conflict-resolve` (new)
- `smart-sync`
- `history`
- `session`
- `workspace status` / `workspace remove` (new)

**Verify existing coverage** for: `init`, `sync`, `status`, `doctor`, `diff`, `log`, `undo`, `config`, `test`, `auto-sync`, all `patch` subcommands, `workspace init/add/list/sync`.

---

## Phase 4: Testing & Documentation

### 4.1 Test coverage gaps (Item #8)

New tests to add to `tests/test_core.py`:

- `test_smart_sync_clean` — no conflicts path
- `test_smart_sync_conflict` — unresolvable conflict returns proper dict
- `test_smart_sync_rerere` — rerere auto-resolves
- `test_smart_sync_circuit_breaker` — 3 failures triggers breaker
- `test_workspace_status` — returns behind/patches/status per repo
- `test_workspace_status_missing` — handles deleted directories
- `test_workspace_remove` — removes by alias
- `test_workspace_remove_not_found` — error for nonexistent alias
- `test_conflict_resolve` — resolves file, continues rebase
- `test_conflict_resolve_multi` — multiple files, returns next conflict
- `test_conflict_resolve_complete` — last file triggers rebase complete
- `test_conflict_resolve_no_rebase` — error when not in rebase
- `test_patch_meta_tags_comma` — comma-separated tags stored individually
- `test_patch_meta_tags_plural` — "tags" key works same as "tag"
- `test_patch_meta_tags_dedup` — duplicate tags not added
- `test_reinit_detection` — reinit flag in result

Add to `tests/test.sh`:
- Section for `conflict-resolve` (human + JSON output)
- Section for `smart-sync` (dry-run equivalent)
- Section for `workspace status` / `workspace remove`

Track `fuzz_mcp.py` — add to git or remove.

### 4.2 CLAUDE.md checklist update (Item #10)

Add to "When adding a new command":
```
4. `bingo-light` — add dedicated formatter (do NOT rely on _format_generic)
```

Add to "When adding a new command":
```
8. `completions/*.bash`, `.zsh`, `.fish` — add to ALL three completion files
```

(Item 8 is currently listed as item 5 but references completions — merge/update numbering.)

### 4.3 CI lint enforcement (Item #11)

Verify the existing GitHub Actions workflow runs `make lint`. If not, add a `lint` job:
```yaml
lint:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: pip install flake8
    - run: sudo apt-get install -y shellcheck
    - run: make lint
```

---

## Dependency Order

```
Phase 1.1 (core split)
  → Phase 1.2 (MCP direct import — depends on package structure)
  → Phase 1.3 (conflict dedup — easier after split)
Phase 2.1 (conflict-resolve — uses deduped _build_conflict_result)
Phase 2.2 (workspace remove — independent)
Phase 3.1-3.3 (UX fixes — independent of each other)
Phase 4.1-4.3 (tests, docs, CI — after all features exist)
```

## Files Changed

| File | Change |
|------|--------|
| `bingo_core.py` | Deleted, replaced by `bingo_core/` package |
| `bingo_core/__init__.py` | New — re-exports, constants |
| `bingo_core/exceptions.py` | New — 5 exception classes |
| `bingo_core/models.py` | New — PatchInfo, ConflictInfo |
| `bingo_core/git.py` | New — Git class |
| `bingo_core/config.py` | New — Config class |
| `bingo_core/state.py` | New — State class |
| `bingo_core/repo.py` | New — Repo class |
| `bingo-light` | conflict-resolve command + formatters |
| `mcp-server.py` | Rewrite to direct import |
| `completions/bingo-light.bash` | Add missing commands |
| `completions/bingo-light.zsh` | Add missing commands |
| `completions/bingo-light.fish` | Add missing commands |
| `tests/test_core.py` | 16+ new tests |
| `tests/test.sh` | New test sections |
| `CLAUDE.md` | Checklist updates |
| `.github/workflows/*.yml` | Lint job |
