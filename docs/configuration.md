# Configuration Reference

Config is stored in `.bingolight` (git-config format). Manage with `bingo-light config`.

## Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `upstream-url` | string | (set at init) | Upstream repository URL |
| `upstream-branch` | string | `main` | Upstream branch to track |
| `patches-branch` | string | `bingo-patches` | Local branch for patches |
| `tracking-branch` | string | `upstream-tracking` | Local mirror of upstream |
| `sync.auto-test` | bool | `false` | Run tests after sync |
| `test.command` | string | (none) | Command to run for `bingo-light test` |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `BINGO_DESCRIPTION` | Set patch description (skips interactive prompt) |
| `BINGO_SCHEDULE` | Set auto-sync schedule ("daily", "6h", "weekly") |
| `BINGO_LIGHT_BIN` | Override bingo-light binary path (for MCP/agent) |
| `NO_COLOR` | Disable colored output (respects no-color.org) |
