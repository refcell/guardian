#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# GitHub repository details
GITHUB_REPO="refcell/guardian"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Claude Code configuration directory
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Secrets Guardian Hook Installer v2.0       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Parse command line arguments
DEBUG_MODE=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) DEBUG_MODE=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ "$DEBUG_MODE" = true ]; then
    echo -e "${CYAN}Debug mode enabled${NC}"
    export GUARDIAN_DEBUG=true
fi

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed. Please install Node.js first.${NC}"
    echo -e "   Visit: https://nodejs.org/"
    exit 1
fi
echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"

if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl is not installed. Please install curl first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ curl found${NC}"

# Check if Claude Code is installed
if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: Claude Code CLI not found in PATH${NC}"
    echo -e "   Make sure Claude Code is properly installed"
fi

# Create directories
echo
echo -e "${YELLOW}Setting up directories...${NC}"
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$HOOKS_DIR"
echo -e "${GREEN}✅ Directories created${NC}"

# Backup existing configuration
if [ -f "$CLAUDE_CONFIG_DIR/settings.json" ]; then
    BACKUP_FILE="$CLAUDE_CONFIG_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CLAUDE_CONFIG_DIR/settings.json" "$BACKUP_FILE"
    echo -e "${GREEN}✅ Backed up existing settings to: $(basename $BACKUP_FILE)${NC}"
fi

# Download hook files
echo
echo -e "${YELLOW}Downloading Guardian components...${NC}"

# Download the main hook script (v2)
echo -n "  Downloading guardian-hook-v2.js... "
curl -sSL "${GITHUB_RAW_URL}/hooks/guardian-hook-v2.js" -o "$HOOKS_DIR/guardian-hook.js" 2>/dev/null || {
    # If v2 doesn't exist yet, fall back to v1
    curl -sSL "${GITHUB_RAW_URL}/hooks/guardian-hook.js" -o "$HOOKS_DIR/guardian-hook.js" 2>/dev/null
}

if [ -f "$HOOKS_DIR/guardian-hook.js" ] && head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "^#\|^/\*"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
    exit 1
fi

# Download the configuration
echo -n "  Downloading secrets-guardian.json... "
curl -sSL "${GITHUB_RAW_URL}/agents/secrets-guardian.json" -o "$HOOKS_DIR/secrets-guardian.json" 2>/dev/null

if [ -f "$HOOKS_DIR/secrets-guardian.json" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
    exit 1
fi

# Make hook executable
chmod +x "$HOOKS_DIR/guardian-hook.js"

# Configure hooks in settings.json
echo
echo -e "${YELLOW}Configuring Claude Code hooks...${NC}"

SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

# Create the new settings using Node.js for proper JSON handling
cat > /tmp/update-claude-settings.js << 'EOJS'
const fs = require('fs');
const path = require('path');

const settingsFile = process.argv[2];
const hooksDir = process.argv[3];

// Load or create settings
let settings = {};
if (fs.existsSync(settingsFile)) {
    try {
        settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
    } catch (e) {
        console.error('Error parsing existing settings:', e.message);
        settings = {};
    }
}

// Initialize hooks section
if (!settings.hooks) {
    settings.hooks = {};
}

// Helper to add or update a hook configuration
function configureHook(eventName, matcher, command, timeout = 60) {
    if (!settings.hooks[eventName]) {
        settings.hooks[eventName] = [];
    }
    
    // Remove existing guardian hooks for this event
    settings.hooks[eventName] = settings.hooks[eventName].filter(config => {
        if (!config.hooks || !Array.isArray(config.hooks)) return true;
        return !config.hooks.some(h => 
            h.command && h.command.includes('guardian-hook')
        );
    });
    
    // Add new configuration
    settings.hooks[eventName].push({
        matcher: matcher,
        hooks: [{
            type: 'command',
            command: path.join(hooksDir, 'guardian-hook.js'),
            timeout: timeout
        }]
    });
}

// Configure multiple hook types for comprehensive coverage

// 1. PreToolUse - Block secrets before tool execution
configureHook('PreToolUse', 'Write|Edit|MultiEdit|Bash|Task', path.join(hooksDir, 'guardian-hook.js'));

// 2. PostToolUse - Log tool usage (optional, for debugging)
if (process.env.GUARDIAN_DEBUG === 'true') {
    configureHook('PostToolUse', 'Write|Edit|MultiEdit|Bash', path.join(hooksDir, 'guardian-hook.js'));
}

// 3. UserPromptSubmit - Scan user prompts for secrets
configureHook('UserPromptSubmit', '.*', path.join(hooksDir, 'guardian-hook.js'));

// 4. Stop - Scan final Claude responses
configureHook('Stop', '.*', path.join(hooksDir, 'guardian-hook.js'));

// 5. SubagentStop - Scan subagent responses
configureHook('SubagentStop', '.*', path.join(hooksDir, 'guardian-hook.js'));

// Write updated settings
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
console.log('Settings updated successfully');
EOJS

node /tmp/update-claude-settings.js "$SETTINGS_FILE" "$HOOKS_DIR"
rm -f /tmp/update-claude-settings.js

echo -e "${GREEN}✅ Hooks configured${NC}"

# Display configuration summary
echo
echo -e "${CYAN}Configured the following hooks:${NC}"
echo -e "  ${BLUE}PreToolUse:${NC} Write, Edit, MultiEdit, Bash, Task"
echo -e "  ${BLUE}UserPromptSubmit:${NC} All user prompts"
echo -e "  ${BLUE}Stop:${NC} All Claude responses"
echo -e "  ${BLUE}SubagentStop:${NC} All subagent responses"
if [ "$DEBUG_MODE" = true ]; then
    echo -e "  ${BLUE}PostToolUse:${NC} Write, Edit, MultiEdit, Bash (debug)"
fi

# Test the installation
echo
echo -e "${YELLOW}Running installation tests...${NC}"

# Test 1: Safe content
echo -n "  Testing safe content... "
test_input='{"tool_name":"Write","tool_input":{"content":"const config = { debug: true };"}}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" 2>/dev/null; then
    echo -e "${GREEN}✅ Passed${NC}"
else
    echo -e "${RED}❌ Failed (should have passed)${NC}"
fi

# Test 2: AWS credentials
echo -n "  Testing AWS credential blocking... "
test_input='{"tool_name":"Write","tool_input":{"content":"AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"}}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" 2>/dev/null; then
    echo -e "${RED}❌ Failed (should have been blocked)${NC}"
else
    echo -e "${GREEN}✅ Blocked${NC}"
fi

# Test 3: API key in bash command
echo -n "  Testing API key in bash command... "
test_input='{"tool_name":"Bash","tool_input":{"command":"export OPENAI_API_KEY=sk-proj-1234567890abcdef"}}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" 2>/dev/null; then
    echo -e "${RED}❌ Failed (should have been blocked)${NC}"
else
    echo -e "${GREEN}✅ Blocked${NC}"
fi

# Test 4: Stop event with secret
echo -n "  Testing Stop event with secret... "
test_input='{"messages":[{"role":"assistant","content":"Your API key is: ghp_1234567890abcdef"}]}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" 2>/dev/null; then
    echo -e "${RED}❌ Failed (should have been blocked)${NC}"
else
    echo -e "${GREEN}✅ Blocked${NC}"
fi

# Test 5: User prompt with password
echo -n "  Testing user prompt with password... "
test_input='{"prompt":"My password is SuperSecret123!"}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" 2>/dev/null; then
    echo -e "${RED}❌ Failed (should have been blocked)${NC}"
else
    echo -e "${GREEN}✅ Blocked${NC}"
fi

# Enable debug mode if requested
if [ "$DEBUG_MODE" = true ]; then
    echo
    echo -e "${CYAN}Debug mode configuration:${NC}"
    echo "  export GUARDIAN_DEBUG=true" >> "$HOME/.bashrc" 2>/dev/null || true
    echo "  export GUARDIAN_DEBUG=true" >> "$HOME/.zshrc" 2>/dev/null || true
    echo -e "${GREEN}✅ Debug logging enabled${NC}"
    echo -e "  Log file: $HOME/.claude/guardian-debug.log"
fi

# Success message
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         🎉 Installation Complete! 🎉                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}The Guardian is now protecting your Claude Code sessions!${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. ${CYAN}Restart Claude Code${NC} if it's currently running"
echo -e "  2. ${CYAN}Test the hook${NC} by trying to write a file with a secret"
echo -e "  3. ${CYAN}Check hook status${NC} with: claude --hooks (or /hooks in interactive mode)"
echo
echo -e "${YELLOW}Troubleshooting:${NC}"
echo -e "  • Run with ${CYAN}--debug${NC} flag to enable debug logging"
echo -e "  • Check logs at: ${CYAN}~/.claude/guardian-debug.log${NC}"
echo -e "  • Verify hooks with: ${CYAN}cat ~/.claude/settings.json | jq .hooks${NC}"
echo
echo -e "${YELLOW}To uninstall:${NC}"
echo -e "  ${CYAN}curl -sSL guardian.refcell.org/uninstall | bash${NC}"
echo