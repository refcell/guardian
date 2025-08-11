#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub repository details
GITHUB_REPO="refcell/guardian"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Claude configuration directory
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"
AGENTS_DIR="$CLAUDE_CONFIG_DIR/agents"

echo -e "${BLUE}=== Claude Secrets Guardian Hook Installer ===${NC}"
echo -e "${BLUE}Installing from: github.com/${GITHUB_REPO}${NC}"
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed. Please install Node.js first.${NC}"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed. Please install curl first.${NC}"
    exit 1
fi

# Create Claude config directories if they don't exist
echo -e "${YELLOW}Creating Claude configuration directories...${NC}"
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$HOOKS_DIR"
mkdir -p "$AGENTS_DIR"

# Download hook files from GitHub
echo -e "${YELLOW}Downloading secrets-guardian hook from GitHub...${NC}"

# Download the secure-command.js hook
curl -sSL "${GITHUB_RAW_URL}/hooks/secure-command.js" -o "$HOOKS_DIR/secure-command.js"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download secure-command.js${NC}"
    exit 1
fi

# Download the agent configuration
curl -sSL "${GITHUB_RAW_URL}/agents/secrets-guardian.json" -o "$AGENTS_DIR/secrets-guardian.json"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download secrets-guardian.json${NC}"
    exit 1
fi

# Make the hook executable
chmod +x "$HOOKS_DIR/secure-command.js"

echo -e "${GREEN}✅ Files downloaded successfully${NC}"

# Create or update Claude settings.json
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Updating existing settings.json...${NC}"
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Use node to update JSON properly
    node -e "
    const fs = require('fs');
    const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
    
    // Initialize hooks if not present
    if (!settings.hooks) {
        settings.hooks = {};
    }
    
    // Add our hook configurations
    settings.hooks['pre-write'] = '$HOOKS_DIR/secure-command.js --file';
    settings.hooks['pre-edit'] = '$HOOKS_DIR/secure-command.js --file';
    settings.hooks['pre-bash'] = '$HOOKS_DIR/secure-command.js --command';
    settings.hooks['pre-commit'] = '$HOOKS_DIR/secure-command.js --file';
    
    fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2));
    "
else
    echo -e "${YELLOW}Creating new settings.json...${NC}"
    cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "pre-write": "$HOOKS_DIR/secure-command.js --file",
    "pre-edit": "$HOOKS_DIR/secure-command.js --file",
    "pre-bash": "$HOOKS_DIR/secure-command.js --command",
    "pre-commit": "$HOOKS_DIR/secure-command.js --file"
  },
  "security": {
    "scan_for_secrets": true,
    "block_on_secrets": true
  }
}
EOF
fi

# Test the installation
echo
echo -e "${YELLOW}Testing installation...${NC}"

# Create a temporary test file
TEMP_TEST_FILE=$(mktemp)
echo "const safe = true;" > "$TEMP_TEST_FILE"

# Test with safe content
echo -e "Testing with safe content..."
if echo "const config = { debug: true };" | node "$HOOKS_DIR/secure-command.js" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Safe content test passed${NC}"
else
    echo -e "${RED}❌ Safe content test failed${NC}"
fi

# Test with secret content
echo -e "Testing with secret content..."
if echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" | node "$HOOKS_DIR/secure-command.js" > /dev/null 2>&1; then
    echo -e "${RED}❌ Secret detection test failed - secrets not blocked${NC}"
else
    echo -e "${GREEN}✅ Secret detection test passed - secrets blocked${NC}"
fi

# Clean up temp file
rm -f "$TEMP_TEST_FILE"

# Verification
echo
echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo -e "${BLUE}Installation Summary:${NC}"
echo "  • Hooks installed to: $HOOKS_DIR"
echo "  • Agent config installed to: $AGENTS_DIR"
echo "  • Settings updated at: $SETTINGS_FILE"
echo
echo -e "${YELLOW}Configured hooks:${NC}"
echo "  • pre-write: Scans files before writing"
echo "  • pre-edit: Scans files before editing"
echo "  • pre-bash: Scans bash commands before execution"
echo "  • pre-commit: Scans files before git commits"
echo
echo -e "${GREEN}The secrets guardian is now active and will block any attempts to expose secrets!${NC}"
echo
echo -e "${BLUE}To verify the installation worked:${NC}"
echo "  1. Try creating a file with a secret in Claude"
echo "  2. The operation should be blocked with a security warning"
echo
echo -e "${YELLOW}To uninstall:${NC}"
echo "  Remove the hook entries from: $SETTINGS_FILE"
echo "  Delete: $HOOKS_DIR/secure-command.js"
echo "  Delete: $AGENTS_DIR/secrets-guardian.json"