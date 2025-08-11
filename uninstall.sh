#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Claude Code configuration directory (correct location)
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

echo -e "${BLUE}=== Claude Secrets Guardian Uninstaller ===${NC}"
echo

# Check if the hook is installed (check all possible locations)
HOOK_INSTALLED=false
if [ -f "$HOOKS_DIR/guardian-hook.js" ] || [ -f "$HOOKS_DIR/session-start-hook.js" ] || [ -f "$HOOKS_DIR/secure-command.js" ] || [ -f "$HOOKS_DIR/guardian-wrapper.sh" ] || [ -f "$HOOKS_DIR/secrets-guardian.json" ]; then
    HOOK_INSTALLED=true
fi

# Also check if there are guardian entries in settings.json
if [ -f "$SETTINGS_FILE" ] && grep -q "guardian" "$SETTINGS_FILE" 2>/dev/null; then
    HOOK_INSTALLED=true
fi

if [ "$HOOK_INSTALLED" = false ]; then
    echo -e "${YELLOW}Guardian hook is not installed.${NC}"
    exit 0
fi

# Check if running interactively (not through pipe)
if [ -t 0 ]; then
    echo -e "${YELLOW}This will remove the Claude Secrets Guardian hook from your system.${NC}"
    echo -n "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Uninstall cancelled.${NC}"
        exit 0
    fi
else
    # Non-interactive mode (piped through curl)
    echo -e "${YELLOW}Removing Claude Secrets Guardian hook...${NC}"
fi

echo

# Remove hook files
if [ -f "$HOOKS_DIR/guardian-hook.js" ]; then
    echo -e "${YELLOW}Removing guardian hook script...${NC}"
    rm -f "$HOOKS_DIR/guardian-hook.js"
    echo -e "${GREEN}✅ Guardian hook removed${NC}"
fi

if [ -f "$HOOKS_DIR/guardian-wrapper.sh" ]; then
    echo -e "${YELLOW}Removing wrapper script...${NC}"
    rm -f "$HOOKS_DIR/guardian-wrapper.sh"
    echo -e "${GREEN}✅ Wrapper script removed${NC}"
fi

if [ -f "$HOOKS_DIR/secure-command.js" ]; then
    echo -e "${YELLOW}Removing legacy hook script...${NC}"
    rm -f "$HOOKS_DIR/secure-command.js"
    echo -e "${GREEN}✅ Legacy hook removed${NC}"
fi

if [ -f "$HOOKS_DIR/secrets-guardian.json" ]; then
    echo -e "${YELLOW}Removing configuration...${NC}"
    rm -f "$HOOKS_DIR/secrets-guardian.json"
    echo -e "${GREEN}✅ Configuration removed${NC}"
fi

if [ -f "$HOOKS_DIR/session-start-hook.js" ]; then
    echo -e "${YELLOW}Removing session start hook...${NC}"
    rm -f "$HOOKS_DIR/session-start-hook.js"
    echo -e "${GREEN}✅ Session start hook removed${NC}"
fi

# Update settings.json if it exists
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Updating settings.json...${NC}"
    
    # Create backup
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Use Node.js to remove hook entries
    if command -v node &> /dev/null; then
        # Check if we're running from the repo or from curl
        if [ -f "scripts/clean-settings.js" ]; then
            # Running from local repo
            node scripts/clean-settings.js 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"✅"* ]]; then
                    echo -e "${GREEN}$line${NC}"
                elif [[ "$line" == *"⚠️"* ]]; then
                    echo -e "${YELLOW}$line${NC}"
                else
                    echo "$line"
                fi
            done
        elif [ -f "$HOOKS_DIR/../scripts/clean-settings.js" ]; then
            # Already installed, use existing script
            node "$HOOKS_DIR/../scripts/clean-settings.js" 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"✅"* ]]; then
                    echo -e "${GREEN}$line${NC}"
                elif [[ "$line" == *"⚠️"* ]]; then
                    echo -e "${YELLOW}$line${NC}"
                else
                    echo "$line"
                fi
            done
        else
            # Download and run the script from GitHub
            curl -sSL "https://raw.githubusercontent.com/refcell/guardian/main/scripts/clean-settings.js" | node 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"✅"* ]]; then
                    echo -e "${GREEN}$line${NC}"
                elif [[ "$line" == *"⚠️"* ]]; then
                    echo -e "${YELLOW}$line${NC}"
                else
                    echo "$line"
                fi
            done
        fi
    else
        echo -e "${YELLOW}⚠️  Node.js not found. Please manually remove hook entries from:${NC}"
        echo "   $SETTINGS_FILE"
        echo
        echo "   Remove these entries from hooks sections:"
        echo '   - PreToolUse: Entries containing "guardian-hook.js"'
        echo '   - Stop: Entries containing "guardian-hook.js"'
        echo '   - SessionStart: Entries containing "session-start-hook.js"'
        echo '   - UserPromptSubmit: Entries containing "guardian-hook.js"'
        echo '   - SubagentStop: Entries containing "guardian-hook.js"'
        echo '   - PostToolUse: Entries containing "guardian-hook.js" (if present)'
    fi
fi

# Clean up empty directories
if [ -d "$HOOKS_DIR" ]; then
    if [ -z "$(ls -A "$HOOKS_DIR")" ]; then
        echo -e "${YELLOW}Removing empty hooks directory...${NC}"
        rmdir "$HOOKS_DIR"
    fi
fi


echo
echo -e "${GREEN}✅ Claude Secrets Guardian has been uninstalled successfully!${NC}"
echo
echo -e "${BLUE}Your Claude configuration has been restored.${NC}"
echo -e "${BLUE}Backup of settings saved to: ${SETTINGS_FILE}.backup.*${NC}"
echo
echo -e "${YELLOW}To reinstall later, run:${NC}"
echo "  curl -sSL guardian.refcell.org/install | bash"