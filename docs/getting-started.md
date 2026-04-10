# Getting Started

## Install

```bash
# Option 1: Direct copy
sudo cp bingo-light /usr/local/bin/

# Option 2: Make install
make install

# Option 3: Just use from the repo
./bingo-light --help
```

## 5-Minute Quickstart

```bash
# 1. You have a forked project
cd my-forked-project

# 2. Initialize bingo-light (point to the original repo)
bingo-light init https://github.com/original/project.git

# 3. Make your customizations
vim src/feature.py

# 4. Save as a named patch
bingo-light patch new my-custom-feature

# 5. Check status anytime
bingo-light status

# 6. Sync with upstream when ready
bingo-light sync
```

## For AI Agents

```bash
# Non-interactive, structured output
bingo-light status --json --yes
bingo-light sync --json --yes
bingo-light conflict-analyze --json
BINGO_DESCRIPTION="add feature" bingo-light patch new feat --yes
```

## MCP Integration

Add to `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "bingo-light": {
      "command": "python3",
      "args": ["/path/to/mcp-server.py"]
    }
  }
}
```
