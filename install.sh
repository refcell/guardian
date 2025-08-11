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
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Claude Secrets Guardian Hook Installer ===${NC}"
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed. Please install Node.js first.${NC}"
    exit 1
fi

# Create Claude config directories if they don't exist
echo -e "${YELLOW}Creating Claude configuration directories...${NC}"
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$HOOKS_DIR"

# Copy hook files
echo -e "${YELLOW}Installing secrets-guardian hook...${NC}"
cp -r "$SCRIPTS_DIR/hooks/secure-command.js" "$HOOKS_DIR/"
cp -r "$SCRIPTS_DIR/agents" "$CLAUDE_CONFIG_DIR/"

# Make the hook executable
chmod +x "$HOOKS_DIR/secure-command.js"

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

# Create test script
echo -e "${YELLOW}Creating test script...${NC}"
cat > "$SCRIPTS_DIR/test-hook.sh" <<'EOF'
#!/bin/bash

echo "Testing Secrets Guardian Hook..."
echo

# Test cases
declare -a test_cases=(
    "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
    "api_key = 'sk-proj-abcdef123456789'"
    "password: supersecret123"
    "mongodb://user:pass@localhost:27017"
    "github_token=ghp_1234567890abcdef"
    "-----BEGIN RSA PRIVATE KEY-----"
)

for test in "${test_cases[@]}"; do
    echo "Testing: ${test:0:30}..."
    result=$(echo "$test" | node hooks/secure-command.js 2>&1)
    status=$?
    
    if [ $status -ne 0 ]; then
        echo "✅ Secret detected and blocked!"
    else
        echo "⚠️  Secret not detected"
    fi
    echo "$result" | jq -r '.status' 2>/dev/null || echo "$result"
    echo "---"
done

echo
echo "Testing safe content..."
result=$(echo "const config = { debug: true };" | node hooks/secure-command.js 2>&1)
status=$?

if [ $status -eq 0 ]; then
    echo "✅ Safe content passed!"
else
    echo "❌ Safe content was blocked"
fi
EOF

chmod +x "$SCRIPTS_DIR/test-hook.sh"

# Verification
echo
echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo -e "${BLUE}Installation Summary:${NC}"
echo "  • Hooks installed to: $HOOKS_DIR"
echo "  • Agent config installed to: $CLAUDE_CONFIG_DIR/agents"
echo "  • Settings updated at: $SETTINGS_FILE"
echo
echo -e "${YELLOW}Configured hooks:${NC}"
echo "  • pre-write: Scans files before writing"
echo "  • pre-edit: Scans files before editing"
echo "  • pre-bash: Scans bash commands before execution"
echo "  • pre-commit: Scans files before git commits"
echo
echo -e "${BLUE}To test the installation:${NC}"
echo "  cd $SCRIPTS_DIR"
echo "  ./test-hook.sh"
echo
echo -e "${GREEN}The secrets guardian is now active and will block any attempts to expose secrets!${NC}"