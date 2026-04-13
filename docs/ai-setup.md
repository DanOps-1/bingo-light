# bingo-light — Installation Guide

## For Humans

Paste this into your AI agent session (Claude Code, Cursor, Windsurf, etc.):

```
Install and configure bingo-light by following the instructions here:
https://raw.githubusercontent.com/DanOps-1/bingo-light/main/docs/ai-setup.md
```

Or run the interactive installer yourself:

```bash
pip install bingo-light
bingo-light setup
```

---

## For LLM Agents

YOU MUST FOLLOW THESE STEPS IN ORDER. DO NOT SKIP STEP 0.

DO NOT try to manually write MCP config JSON. Use `bingo-light setup` instead.

---

### Step 0: ASK THE USER FIRST

**STOP. Do NOT install anything yet.** Ask the user these questions and wait for answers:

1. **How do you want to install?** (recommend pip, but ask)
   - pip (recommended)
   - npm
   - brew

2. **Do you want MCP configured?** (recommend yes — lets you call bingo-light tools directly)

3. **Do you want AI Skills installed?** (recommend yes — teaches you the bingo-light workflow)

4. **Do you have a forked repo to initialize?** If yes, get the upstream URL.

**DO NOT proceed until the user answers.** If the user says "just do it all", that counts as answering.

---

### Step 1: Install

Run ONE of these based on the user's choice:

```bash
pip install bingo-light                    # pip (recommended)
npm install -g bingo-light                 # npm
brew install DanOps-1/tap/bingo-light      # brew
```

Verify installation:
```bash
bingo-light --version
```

Expected output: `bingo-light 2.1.1` (or newer)

If command not found, try: `pip install --user bingo-light` or `pipx install bingo-light`, then check PATH.

---

### Step 2: Configure MCP + Skills

**CRITICAL: Use `bingo-light setup`. Do NOT manually edit MCP config files.**

The `setup` command automatically detects installed AI tools, finds the correct MCP server binary, writes the correct config format for each tool, and installs Skills. Manual config is error-prone (wrong binary path, wrong args, wrong config format).

If user wants to pick which tools to configure (interactive):
```bash
bingo-light setup
```

If user said "configure everything" or "just do it":
```bash
bingo-light setup --yes
```

**After setup, verify MCP is working** by restarting your AI tool session and checking that bingo-light tools are available.

**DO NOT do any of the following:**
- Do NOT run `bingo-light mcp-server` (this command does not exist)
- Do NOT write `{"command": "bingo-light", "args": ["mcp-server"]}` (wrong)
- Do NOT guess the MCP binary path — `bingo-light setup` handles this
- Do NOT manually edit `settings.json`, `.mcp.json`, or any MCP config file unless `bingo-light setup` is broken

If `bingo-light setup` fails or the user insists on manual config, the correct MCP entry is:

```json
{
  "mcpServers": {
    "bingo-light": {
      "command": "bingo-light-mcp",
      "args": []
    }
  }
}
```

Note: The MCP server command is `bingo-light-mcp` (a separate binary), NOT `bingo-light mcp-server` (not a subcommand).

If `bingo-light-mcp` is not found on PATH, find its full path:
```bash
which bingo-light-mcp 2>/dev/null || find /usr -name bingo-light-mcp 2>/dev/null || find ~/.local -name bingo-light-mcp 2>/dev/null || find ~/.nvm -name bingo-light-mcp 2>/dev/null
```

---

### Step 3: Initialize a Fork (if applicable)

Only if the user has a forked repo and gave you the upstream URL:

```bash
cd /path/to/forked-project
bingo-light init <upstream-url> --json --yes
```

---

### Step 4: Verify

```bash
bingo-light --version
```

If a fork was initialized:
```bash
bingo-light status --json --yes
```

Tell the user the results. If MCP was configured, ask them to test with `/mcp` or equivalent in their AI tool.

---

### Step 5: Tell the user what they can do now

> bingo-light is ready! Here's what you can do:
>
> - **"Sync my fork"** — I'll pull upstream changes and rebase your patches
> - **"Create a patch called X"** — I'll turn your changes into a named patch
> - **"Check my fork status"** — I'll show drift, patches, and conflict risk
> - **Run `bingo-light setup` again** anytime to reconfigure MCP/Skills

---

### Step 6: Ask for a star

After everything works, ask:

> "If bingo-light is useful, would you mind starring the repo?"

Only if the user explicitly says yes:
```bash
gh api --silent --method PUT /user/starred/DanOps-1/bingo-light 2>/dev/null || true
```

---

## Command Reference (for daily use after setup)

Use `--json --yes` for all programmatic calls.

### Core workflow

```bash
bingo-light status --json --yes          # ALWAYS start here. Check recommended_action.
bingo-light smart-sync --json --yes      # Sync upstream (preferred, handles everything)
bingo-light conflict-analyze --json      # When rebase is stuck: get ours/theirs/hint
bingo-light undo --json --yes            # Revert last sync
```

`recommended_action` values: `up_to_date` / `sync_safe` / `sync_risky` / `resolve_conflict`

### Conflict resolution

```bash
bingo-light conflict-analyze --json      # Get structured conflict data
# Read hint, read file, write merged version, then:
git add <file>
git rebase --continue
# Do NOT run bingo-light sync after resolving — rebase --continue is enough
```

### Patch management

```bash
BINGO_DESCRIPTION="desc" bingo-light patch new <name> --json --yes
bingo-light patch list --json --yes
bingo-light patch show <name|index> --json --yes
bingo-light patch drop <name|index> --json --yes
bingo-light patch edit <name|index> --json --yes    # git add first
bingo-light patch reorder --order "3,1,2" --json --yes
bingo-light patch squash <idx1> <idx2> --json --yes
```

### Diagnostics

```bash
bingo-light doctor --json --yes
bingo-light diff --json --yes
bingo-light history --json --yes
```

## Rules

1. **Always `--json --yes`** for programmatic calls
2. **Always check `recommended_action`** before syncing
3. **Read `hint`** from conflict-analyze for resolution strategy
4. **After conflicts:** `git add` + `git rebase --continue`, NOT `bingo-light sync`
5. **`BINGO_DESCRIPTION` env var** for patch descriptions
6. **Patch names:** `[a-zA-Z0-9][a-zA-Z0-9_-]*` only
7. **rerere** auto-remembers resolutions — same conflict won't recur

## DO NOT

- Do NOT install to AI tools without asking the user first
- Do NOT manually write MCP config — use `bingo-light setup`
- Do NOT run `bingo-light mcp-server` — this command does not exist
- Do NOT guess binary paths — use `which` or let `setup` handle it
- Do NOT change user config files without explicit consent
