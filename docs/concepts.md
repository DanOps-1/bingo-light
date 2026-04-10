# Concepts

## Branch Model

```
upstream (github.com/original/project)
    |
    |  git fetch
    v
upstream-tracking -------- exact mirror of upstream, never modified manually
    |
    |  rebase
    v
pingo-patches ------------ your customizations live here
    |
    +-- [pl] dark-mode:     support dark color scheme
    +-- [pl] api-cache:     add Redis caching layer
    +-- [pl] fix-typo:      fix README typo
```

## Patch Stack

Each customization is one git commit with a `[pl]` prefix. Patches are ordered — bottom patches are applied first.

Operations: `patch new`, `patch list`, `patch show`, `patch edit`, `patch drop`, `patch reorder`, `patch squash`, `patch export/import`.

## Sync Flow

`pingo-light sync` does:
1. `git fetch upstream`
2. Fast-forward `upstream-tracking` to `upstream/main`
3. `git rebase --onto upstream-tracking <old-base> pingo-patches`

Your patches are replayed on top of the latest upstream. If a patch conflicts, the rebase pauses for you to resolve.

## Conflict Resolution

- **git rerere** is auto-enabled: resolved conflicts are remembered
- **diff3 merge style** shows the common ancestor in conflict markers
- `pingo-light conflict-analyze --json` gives structured conflict info for AI agents
- `pingo-light undo` reverts the last sync if something goes wrong

## Patch Metadata

Optional metadata stored in `.pingo/metadata.json`:
- **reason**: why this patch exists
- **tags**: categorization (bugfix, feature, temporary)
- **expires**: when to reconsider this patch
- **upstream_pr**: link to the PR you submitted upstream
- **status**: permanent or temporary

## Sync History

Every successful sync is recorded in `.pingo/sync-history.json` with:
- Timestamp
- Upstream commit range integrated
- Patch hash mapping (old hash → new hash after rebase)

## Hooks

Executable scripts in `.pingo/hooks/` are called after key events:
- `on-sync-success` — after clean sync
- `on-conflict` — when sync hits a conflict
- `on-test-fail` — when `sync --test` fails

Hooks receive JSON data on stdin.

## Workspace

Manage multiple forks from one place:
- `workspace init` — create workspace config
- `workspace add /path/to/fork` — register a repo
- `workspace status` — overview of all repos
- `workspace sync` — sync all repos that are safe
