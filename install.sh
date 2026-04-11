#!/usr/bin/env bash
# bingo-light installer — interactive setup wizard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
    BLUE='\033[0;34m' CYAN='\033[0;36m' BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

info()    { echo -e "${BLUE}>${RESET} $*"; }
success() { echo -e "${GREEN}OK${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }

ask() {
    local prompt="$1" default="${2:-y}"
    echo -ne "  $prompt "
    read -r answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy] ]]
}

# ─── Header ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}  bingo-light installer${RESET}"
echo -e "${DIM}  AI-native fork maintenance tool${RESET}"
echo ""
echo "  This will set up:"
echo -e "  ${CYAN}1${RESET} CLI tool         (bingo-light command)"
echo -e "  ${CYAN}2${RESET} Shell completions (tab completion for bash/zsh/fish)"
echo -e "  ${CYAN}3${RESET} MCP server        (AI tool integration for Claude Code, Cursor, etc.)"
echo -e "  ${CYAN}4${RESET} AI skill          (/bingo slash command for Claude Code)"
echo ""

# ─── Step 1: CLI ──────────────────────────────────────────────────────────────

echo -e "${BOLD}Step 1: Install CLI${RESET}"

INSTALL_DIR="/usr/local/bin"
if [[ ! -w "$INSTALL_DIR" ]]; then
    info "Installing bingo-light to $INSTALL_DIR (requires sudo)..."
    sudo install -m 755 "$SCRIPT_DIR/bingo-light" "$INSTALL_DIR/bingo-light"
else
    install -m 755 "$SCRIPT_DIR/bingo-light" "$INSTALL_DIR/bingo-light"
fi
success "bingo-light installed to $INSTALL_DIR/bingo-light"
echo ""

# ─── Step 2: Shell Completions ────────────────────────────────────────────────

echo -e "${BOLD}Step 2: Shell Completions${RESET}"

SHELL_NAME=$(basename "${SHELL:-/bin/bash}")
case "$SHELL_NAME" in
    bash)
        COMP_DIR="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions}"
        mkdir -p "$COMP_DIR"
        cp "$SCRIPT_DIR/completions/bingo-light.bash" "$COMP_DIR/bingo-light"
        success "Bash completions installed to $COMP_DIR/bingo-light"
        ;;
    zsh)
        COMP_DIR="${HOME}/.zfunc"
        mkdir -p "$COMP_DIR"
        cp "$SCRIPT_DIR/completions/bingo-light.zsh" "$COMP_DIR/_bingo-light"
        # Ensure .zfunc is in fpath
        if ! grep -q '.zfunc' ~/.zshrc 2>/dev/null; then
            echo 'fpath=(~/.zfunc $fpath)' >> ~/.zshrc
            echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
            info "Added ~/.zfunc to fpath in ~/.zshrc"
        fi
        success "Zsh completions installed to $COMP_DIR/_bingo-light"
        ;;
    fish)
        COMP_DIR="${HOME}/.config/fish/completions"
        mkdir -p "$COMP_DIR"
        cp "$SCRIPT_DIR/completions/bingo-light.fish" "$COMP_DIR/bingo-light.fish"
        success "Fish completions installed to $COMP_DIR/bingo-light.fish"
        ;;
    *)
        warn "Unknown shell '$SHELL_NAME', skipping completions."
        ;;
esac
echo ""

# ─── Step 3: MCP Server ──────────────────────────────────────────────────────

echo -e "${BOLD}Step 3: MCP Server (AI Tool Integration)${RESET}"
echo ""
echo "  The MCP server lets AI assistants (Claude Code, Cursor, etc.)"
echo "  call bingo-light commands directly as tools."
echo ""

MCP_CONFIGURED=false

# Detect Claude Code
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]]; then
    if ask "Set up MCP for Claude Code? [Y/n]"; then
        mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

        MCP_ENTRY='"bingo-light":{"command":"python3","args":["'"$SCRIPT_DIR/mcp-server.py"'"]}'

        if [[ -f "$CLAUDE_SETTINGS" ]]; then
            # Check if already configured
            if grep -q "bingo-light" "$CLAUDE_SETTINGS" 2>/dev/null; then
                success "Already configured in $CLAUDE_SETTINGS"
            else
                # Add to existing mcpServers or create the section
                python3 -c "
import json, sys
with open('$CLAUDE_SETTINGS') as f: data = json.load(f)
servers = data.setdefault('mcpServers', {})
servers['bingo-light'] = {'command': 'python3', 'args': ['$SCRIPT_DIR/mcp-server.py']}
with open('$CLAUDE_SETTINGS', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null && success "Added to $CLAUDE_SETTINGS" || warn "Could not update settings, add manually"
            fi
        else
            # Create new settings file
            python3 -c "
import json
data = {'mcpServers': {'bingo-light': {'command': 'python3', 'args': ['$SCRIPT_DIR/mcp-server.py']}}}
with open('$CLAUDE_SETTINGS', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null && success "Created $CLAUDE_SETTINGS" || warn "Could not create settings"
        fi
        MCP_CONFIGURED=true
    fi
    echo ""
fi

# Detect Claude Desktop (macOS)
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [[ -d "$HOME/Library/Application Support/Claude" ]]; then
    if ask "Set up MCP for Claude Desktop? [Y/n]"; then
        if [[ -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
            if grep -q "bingo-light" "$CLAUDE_DESKTOP_CONFIG" 2>/dev/null; then
                success "Already configured in Claude Desktop"
            else
                python3 -c "
import json
with open('$CLAUDE_DESKTOP_CONFIG') as f: data = json.load(f)
servers = data.setdefault('mcpServers', {})
servers['bingo-light'] = {'command': 'python3', 'args': ['$SCRIPT_DIR/mcp-server.py']}
with open('$CLAUDE_DESKTOP_CONFIG', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null && success "Added to Claude Desktop config" || warn "Could not update config"
            fi
        else
            python3 -c "
import json
data = {'mcpServers': {'bingo-light': {'command': 'python3', 'args': ['$SCRIPT_DIR/mcp-server.py']}}}
with open('$CLAUDE_DESKTOP_CONFIG', 'w') as f: json.dump(data, f, indent=2)
" 2>/dev/null && success "Created Claude Desktop config" || warn "Could not create config"
        fi
        MCP_CONFIGURED=true
    fi
    echo ""
fi

if [[ "$MCP_CONFIGURED" == false ]]; then
    info "To set up MCP manually for other clients, add this to your MCP config:"
    echo ""
    echo -e "  ${DIM}{${RESET}"
    echo -e "  ${DIM}  \"mcpServers\": {${RESET}"
    echo -e "  ${DIM}    \"bingo-light\": {${RESET}"
    echo -e "  ${DIM}      \"command\": \"python3\",${RESET}"
    echo -e "  ${DIM}      \"args\": [\"$SCRIPT_DIR/mcp-server.py\"]${RESET}"
    echo -e "  ${DIM}    }${RESET}"
    echo -e "  ${DIM}  }${RESET}"
    echo -e "  ${DIM}}${RESET}"
    echo ""
fi

# ─── Step 4: AI Skill ────────────────────────────────────────────────────────

echo -e "${BOLD}Step 4: AI Skill (/bingo slash command)${RESET}"
echo ""
echo "  The /bingo skill teaches AI how to use bingo-light CLI."
echo "  When you type /bingo in Claude Code, the AI gets a full command reference."
echo ""

SKILL_SRC="$SCRIPT_DIR/.claude/commands/bingo.md"
if [[ -f "$SKILL_SRC" ]]; then
    # Global skill (works everywhere)
    GLOBAL_CMD_DIR="$HOME/.claude/commands"
    if ask "Install /bingo as global slash command? [Y/n]"; then
        mkdir -p "$GLOBAL_CMD_DIR"
        cp "$SKILL_SRC" "$GLOBAL_CMD_DIR/bingo.md"
        success "Installed /bingo globally to $GLOBAL_CMD_DIR/bingo.md"
    fi
else
    warn "Skill file not found at $SKILL_SRC"
fi
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GREEN}Installation complete!${RESET}"
echo ""
echo -e "  ${CYAN}CLI:${RESET}         bingo-light --help"
echo -e "  ${CYAN}Completions:${RESET} restart your shell or source your rc file"
echo -e "  ${CYAN}MCP:${RESET}         restart Claude Code / Claude Desktop to load"
echo -e "  ${CYAN}Skill:${RESET}       type ${BOLD}/bingo${RESET} in Claude Code"
echo ""
echo -e "  ${BOLD}Quick start:${RESET}"
echo -e "    cd your-forked-project"
echo -e "    bingo-light init https://github.com/original/project.git"
echo -e "    bingo-light patch new my-feature"
echo -e "    bingo-light sync"
echo ""
echo -e "  ${DIM}Or just tell AI: /bingo${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
