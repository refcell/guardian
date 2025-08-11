#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Claude configuration directory
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"
AGENTS_DIR="$CLAUDE_CONFIG_DIR/agents"
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

echo -e "${BLUE}=== Claude Secrets Guardian Uninstaller ===${NC}"
echo

# Check if the hook is installed
if [ ! -f "$HOOKS_DIR/secure-command.js" ] && [ ! -f "$AGENTS_DIR/secrets-guardian.json" ]; then
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
if [ -f "$HOOKS_DIR/secure-command.js" ]; then
    echo -e "${YELLOW}Removing hook script...${NC}"
    rm -f "$HOOKS_DIR/secure-command.js"
    echo -e "${GREEN}✅ Hook script removed${NC}"
fi

# Remove agent configuration
if [ -f "$AGENTS_DIR/secrets-guardian.json" ]; then
    echo -e "${YELLOW}Removing agent configuration...${NC}"
    rm -f "$AGENTS_DIR/secrets-guardian.json"
    echo -e "${GREEN}✅ Agent configuration removed${NC}"
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
            
            // Remove guardian hook entries
            if (settings.hooks) {
                const hooksToRemove = ['pre-write', 'pre-edit', 'pre-bash', 'pre-commit'];
                hooksToRemove.forEach(hook => {
                    if (settings.hooks[hook] && settings.hooks[hook].includes('secure-command.js')) {
                        delete settings.hooks[hook];
                    }
                });
                
                // Remove empty hooks object
                if (Object.keys(settings.hooks).length === 0) {
                    delete settings.hooks;
                }
            }
            
            // Remove security settings if they were added by guardian
            if (settings.security && 
                settings.security.scan_for_secrets === true && 
                settings.security.block_on_secrets === true) {
                delete settings.security;
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
        echo "   Remove these entries:"
        echo '   - hooks["pre-write"] containing "secure-command.js"'
        echo '   - hooks["pre-edit"] containing "secure-command.js"'
        echo '   - hooks["pre-bash"] containing "secure-command.js"'
        echo '   - hooks["pre-commit"] containing "secure-command.js"'
    fi
fi

# Clean up empty directories
if [ -d "$HOOKS_DIR" ]; then
    if [ -z "$(ls -A "$HOOKS_DIR")" ]; then
        echo -e "${YELLOW}Removing empty hooks directory...${NC}"
        rmdir "$HOOKS_DIR"
    fi
fi

if [ -d "$AGENTS_DIR" ]; then
    if [ -z "$(ls -A "$AGENTS_DIR")" ]; then
        echo -e "${YELLOW}Removing empty agents directory...${NC}"
        rmdir "$AGENTS_DIR"
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