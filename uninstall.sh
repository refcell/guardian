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

# Check if the hook is installed
if [ ! -f "$HOOKS_DIR/secure-command.js" ] && [ ! -f "$HOOKS_DIR/guardian-wrapper.sh" ]; then
    echo -e "${YELLOW}Guardian hook is not installed.${NC}"
    exit 0
fi

echo -e "${YELLOW}This will remove the Claude Secrets Guardian hook from your system.${NC}"
echo -n "Are you sure you want to continue? (y/N): "
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Uninstall cancelled.${NC}"
    exit 0
fi

echo

# Remove hook files
if [ -f "$HOOKS_DIR/guardian-wrapper.sh" ]; then
    echo -e "${YELLOW}Removing wrapper script...${NC}"
    rm -f "$HOOKS_DIR/guardian-wrapper.sh"
    echo -e "${GREEN}✅ Wrapper script removed${NC}"
fi

if [ -f "$HOOKS_DIR/secure-command.js" ]; then
    echo -e "${YELLOW}Removing hook script...${NC}"
    rm -f "$HOOKS_DIR/secure-command.js"
    echo -e "${GREEN}✅ Hook script removed${NC}"
fi

if [ -f "$HOOKS_DIR/secrets-guardian.json" ]; then
    echo -e "${YELLOW}Removing configuration...${NC}"
    rm -f "$HOOKS_DIR/secrets-guardian.json"
    echo -e "${GREEN}✅ Configuration removed${NC}"
fi

# Update settings.json if it exists
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Updating settings.json...${NC}"
    
    # Create backup
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Use Node.js to remove hook entries
    if command -v node &> /dev/null; then
        node -e "
        const fs = require('fs');
        try {
            const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
            
            // Remove guardian hook entries from PreToolUse
            if (settings.hooks && settings.hooks.PreToolUse) {
                const toolsToClean = ['Write', 'Edit', 'MultiEdit', 'Bash'];
                toolsToClean.forEach(tool => {
                    if (settings.hooks.PreToolUse[tool] && 
                        settings.hooks.PreToolUse[tool].includes('guardian-wrapper.sh')) {
                        delete settings.hooks.PreToolUse[tool];
                    }
                });
                
                // Remove empty PreToolUse object
                if (Object.keys(settings.hooks.PreToolUse).length === 0) {
                    delete settings.hooks.PreToolUse;
                }
                
                // Remove empty hooks object
                if (Object.keys(settings.hooks).length === 0) {
                    delete settings.hooks;
                }
            }
            
            fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2));
            console.log('✅ Settings updated');
        } catch (error) {
            console.error('⚠️  Could not update settings.json automatically');
            console.error('   Please manually remove hook entries from: $SETTINGS_FILE');
        }
        " 2>&1 | while IFS= read -r line; do
            if [[ "$line" == *"✅"* ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" == *"⚠️"* ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  Node.js not found. Please manually remove hook entries from:${NC}"
        echo "   $SETTINGS_FILE"
        echo
        echo "   Remove these entries from hooks.PreToolUse:"
        echo '   - Write: containing "guardian-wrapper.sh"'
        echo '   - Edit: containing "guardian-wrapper.sh"'
        echo '   - MultiEdit: containing "guardian-wrapper.sh"'
        echo '   - Bash: containing "guardian-wrapper.sh"'
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