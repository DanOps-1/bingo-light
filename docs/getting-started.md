# Getting Started

## Install

```bash
# Option 1: Direct copy
sudo cp pingo-light /usr/local/bin/

# Option 2: Make install
make install

# Option 3: Just use from the repo
./pingo-light --help
```

## 5-Minute Quickstart

```bash
# 1. You have a forked project
cd my-forked-project

# 2. Initialize pingo-light (point to the original repo)
pingo-light init https://github.com/original/project.git

# 3. Make your customizations
vim src/feature.py

# 4. Save as a named patch
pingo-light patch new my-custom-feature

# 5. Check status anytime
pingo-light status

# 6. Sync with upstream when ready
pingo-light sync
```

## For AI Agents

```bash
# Non-interactive, structured output
pingo-light status --json --yes
pingo-light sync --json --yes
pingo-light conflict-analyze --json
PINGO_DESCRIPTION="add feature" pingo-light patch new feat --yes
```

## MCP Integration

Add to `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "pingo-light": {
      "command": "python3",
      "args": ["/path/to/mcp-server.py"]
    }
  }
}
```
