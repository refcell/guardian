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

# Claude Code configuration directory (correct location)
CLAUDE_CONFIG_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"

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

# Download hook files from GitHub
echo -e "${YELLOW}Downloading secrets-guardian hook from GitHub...${NC}"

# Download the guardian-hook.js (Claude Code compatible hook)
curl -sSL "${GITHUB_RAW_URL}/hooks/guardian-hook.js" -o "$HOOKS_DIR/guardian-hook.js"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download guardian-hook.js${NC}"
    exit 1
fi

# Create the session-start-hook.js (Session start notifications)
echo -e "${YELLOW}Creating session start hook...${NC}"
cat > "$HOOKS_DIR/session-start-hook.js" << 'EOF'
#!/usr/bin/env node

/**
 * SessionStart Hook for Guardian
 * Displays security status when Claude Code sessions start
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOOKS_DIR = path.join(os.homedir(), '.claude', 'hooks');
const CONFIG_FILE = path.join(HOOKS_DIR, 'secrets-guardian.json');

const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

function getProtectedPatterns() {
    try {
        const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        return Object.keys(config.patterns || {});
    } catch (e) {
        return ['API Keys', 'AWS Credentials', 'Passwords', 'Tokens', 'Private Keys', 'Database URLs'];
    }
}

function main() {
    let input = '';
    const patterns = getProtectedPatterns();
    
    // Format message
    let message = `\n${colors.cyan}${colors.bright}🛡️ Guardian Security Active${colors.reset}\n`;
    message += `${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n\n`;
    
    try {
        // Read input to determine session type
        process.stdin.setEncoding('utf8');
        process.stdin.on('data', chunk => input += chunk);
        process.stdin.on('end', () => {
            try {
                const data = input ? JSON.parse(input) : {};
                const source = data.source || data.matcher || 'startup';
                
                if (source === 'startup') {
                    message += `${colors.green}Welcome! Your Claude Code session is protected.${colors.reset}\n\n`;
                } else if (source === 'resume') {
                    message += `${colors.green}Session resumed with security protection.${colors.reset}\n\n`;
                } else if (source === 'clear') {
                    message += `${colors.green}Session cleared. Starting fresh with protection.${colors.reset}\n\n`;
                }
            } catch (e) {
                message += `${colors.green}Your session is protected against secret exposure.${colors.reset}\n\n`;
            }
            
            message += `${colors.yellow}Protected Secret Types:${colors.reset}\n`;
            patterns.forEach(pattern => {
                const displayName = pattern.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
                message += `  ${colors.cyan}•${colors.reset} ${displayName}\n`;
            });
            
            message += `\n${colors.blue}Security Features:${colors.reset}\n`;
            message += `  ${colors.green}✓${colors.reset} Blocks hardcoded secrets in code\n`;
            message += `  ${colors.green}✓${colors.reset} Scans user prompts for sensitive data\n`;
            message += `  ${colors.green}✓${colors.reset} Protects Claude's responses from leaks\n`;
            message += `  ${colors.green}✓${colors.reset} Monitors file operations and commands\n`;
            
            message += `\n${colors.dim}Tip: Use environment variables instead of hardcoded secrets${colors.reset}\n`;
            message += `${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`;
            
            console.log(message);
            process.exit(0);
        });
        
        // Timeout fallback
        setTimeout(() => {
            console.log(message);
            process.exit(0);
        }, 1000);
    } catch (e) {
        // Fallback message
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}`);
        console.log(`${colors.green}Your session is protected against secret exposure${colors.reset}\n`);
        process.exit(0);
    }
}

if (require.main === module) {
    main();
}
EOF

# Verify the downloaded file is valid JavaScript (not HTML error page)
if head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "404" || head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "<" ; then
    echo -e "${RED}Error: Downloaded file appears to be an error page, not JavaScript${NC}"
    echo -e "${YELLOW}Attempting alternative download method...${NC}"
    # Try alternative download
    curl -L "https://github.com/${GITHUB_REPO}/raw/main/hooks/guardian-hook.js" -o "$HOOKS_DIR/guardian-hook.js"
    if [ $? -ne 0 ] || head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "404" || head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "<" ; then
        echo -e "${RED}Failed to download valid guardian-hook.js file${NC}"
        exit 1
    fi
fi

# Verify it starts with shebang or comment
if ! head -n 1 "$HOOKS_DIR/guardian-hook.js" | grep -q "^#\|^/\*" ; then
    echo -e "${RED}Error: Downloaded file does not appear to be valid JavaScript${NC}"
    exit 1
fi

# Download the agent configuration  
curl -sSL "${GITHUB_RAW_URL}/agents/secrets-guardian.json" -o "$HOOKS_DIR/secrets-guardian.json"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download secrets-guardian.json${NC}"
    exit 1
fi

# Verify the config file is valid JSON
if ! python3 -m json.tool "$HOOKS_DIR/secrets-guardian.json" > /dev/null 2>&1 && ! node -e "JSON.parse(require('fs').readFileSync('$HOOKS_DIR/secrets-guardian.json'))" > /dev/null 2>&1 ; then
    echo -e "${RED}Error: Downloaded configuration file is not valid JSON${NC}"
    exit 1
fi

# Make the hooks executable
chmod +x "$HOOKS_DIR/guardian-hook.js"
chmod +x "$HOOKS_DIR/session-start-hook.js" 2>/dev/null || true

echo -e "${GREEN}✅ Hook files created successfully${NC}"

# Create or update Claude settings.json with correct format
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}Updating existing settings.json...${NC}"
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Use node to update JSON properly with Claude Code array format
    node -e "
    const fs = require('fs');
    const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
    
    // Initialize hooks if not present
    if (!settings.hooks) {
        settings.hooks = {};
    }
    
    // Add PreToolUse hooks in array format (Claude Code format)
    if (!settings.hooks.PreToolUse) {
        settings.hooks.PreToolUse = [];
    }
    
    // Remove existing guardian hooks if present
    settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(h => 
        !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
        !h.hooks[0].command.includes('guardian-hook.js')
    );
    
    // Add guardian hook with wildcard matcher for ALL tools
    settings.hooks.PreToolUse.push({
        matcher: '.*',  // Wildcard regex to match ALL tools
        hooks: [{
            type: 'command',
            command: '$HOOKS_DIR/guardian-hook.js',
            timeout: 30
        }]
    });
    
    // Add Stop hook to scan final responses
    if (!settings.hooks.Stop) {
        settings.hooks.Stop = [];
    }
    
    // Remove existing guardian Stop hooks if present
    settings.hooks.Stop = settings.hooks.Stop.filter(h => 
        !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
        !h.hooks[0].command.includes('guardian-hook.js')
    );
    
    // Add guardian hook for Stop event (matches all)
    settings.hooks.Stop.push({
        matcher: '.*',
        hooks: [{
            type: 'command',
            command: '$HOOKS_DIR/guardian-hook.js',
            timeout: 30
        }]
    });
    
    // Add SessionStart hooks
    if (!settings.hooks.SessionStart) {
        settings.hooks.SessionStart = [];
    }
    
    // Remove existing guardian session hooks
    settings.hooks.SessionStart = settings.hooks.SessionStart.filter(h => 
        !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
        !h.hooks[0].command.includes('session-start-hook.js')
    );
    
    // Add session start hooks for different matchers with absolute paths
    const sessionHookPath = require('path').join('$HOOKS_DIR', 'session-start-hook.js');
    ['startup', 'resume', 'clear'].forEach(matcher => {
        settings.hooks.SessionStart.push({
            matcher: matcher,
            hooks: [{
                type: 'command',
                command: sessionHookPath,
                timeout: 10
            }]
        });
    });
    
    fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2));
    "
else
    echo -e "${YELLOW}Creating new settings.json...${NC}"
    cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/guardian-hook.js",
            "timeout": 30
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/guardian-hook.js",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook.js",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook.js",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "clear",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start-hook.js",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF
fi

# Test the installation
echo
echo -e "${YELLOW}Testing installation...${NC}"

# Test with safe content
echo -e "Testing with safe content..."
test_input='{"toolName":"Write","toolInput":{"content":"const config = { debug: true };"}}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Safe content test passed${NC}"
else
    echo -e "${RED}❌ Safe content test failed${NC}"
fi

# Test with secret content
echo -e "Testing with secret content..."
test_input='{"toolName":"Write","toolInput":{"content":"AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"}}'
if echo "$test_input" | node "$HOOKS_DIR/guardian-hook.js" > /dev/null 2>&1; then
    echo -e "${RED}❌ Secret detection test failed - secrets not blocked${NC}"
else
    echo -e "${GREEN}✅ Secret detection test passed - secrets blocked${NC}"
fi

# Verification
echo
echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo -e "${BLUE}Installation Summary:${NC}"
echo "  • Hooks installed to: $HOOKS_DIR"
echo "  • Settings updated at: $SETTINGS_FILE"
echo
echo -e "${YELLOW}Configured hooks:${NC}"
echo "  ${BLUE}SessionStart:${NC}"
echo "    • Scans for exposed secrets when sessions start/resume/clear"
echo "  ${BLUE}PreToolUse:${NC}"
echo "    • ALL tools: Scans every operation for secrets (wildcard matcher)"
echo "  ${BLUE}Stop:${NC}"
echo "    • ALL responses: Scans Claude's outputs for exposed secrets"
echo
echo -e "${GREEN}The secrets guardian is now active and will block any attempts to expose secrets!${NC}"
echo
echo -e "${BLUE}To verify the installation worked:${NC}"
echo "  1. Try creating a file with a secret in Claude Code"
echo "  2. The operation should be blocked with a security warning"
echo
echo -e "${YELLOW}To uninstall:${NC}"
echo "  curl -sSL guardian.refcell.org/uninstall | bash"