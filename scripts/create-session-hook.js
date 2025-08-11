#!/usr/bin/env node

/**
 * Creates the session-start-hook.js file for Guardian
 * This script generates the SessionStart hook that displays security status
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOOKS_DIR = path.join(os.homedir(), '.claude', 'hooks');
const SESSION_HOOK_FILE = path.join(HOOKS_DIR, 'session-start-hook.js');

const sessionHookContent = `#!/usr/bin/env node

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
    reset: '\\x1b[0m',
    bright: '\\x1b[1m',
    dim: '\\x1b[2m',
    red: '\\x1b[31m',
    green: '\\x1b[32m',
    yellow: '\\x1b[33m',
    blue: '\\x1b[34m',
    cyan: '\\x1b[36m'
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
    let message = \`\\n\${colors.cyan}\${colors.bright}🛡️ Guardian Security Active\${colors.reset}\\n\`;
    message += \`\${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${colors.reset}\\n\\n\`;
    
    try {
        // Read input to determine session type
        process.stdin.setEncoding('utf8');
        process.stdin.on('data', chunk => input += chunk);
        process.stdin.on('end', () => {
            try {
                const data = input ? JSON.parse(input) : {};
                const source = data.source || data.matcher || 'startup';
                
                if (source === 'startup') {
                    message += \`\${colors.green}Welcome! Your Claude Code session is protected.\${colors.reset}\\n\\n\`;
                } else if (source === 'resume') {
                    message += \`\${colors.green}Session resumed with security protection.\${colors.reset}\\n\\n\`;
                } else if (source === 'clear') {
                    message += \`\${colors.green}Session cleared. Starting fresh with protection.\${colors.reset}\\n\\n\`;
                }
            } catch (e) {
                message += \`\${colors.green}Your session is protected against secret exposure.\${colors.reset}\\n\\n\`;
            }
            
            message += \`\${colors.yellow}Protected Secret Types:\${colors.reset}\\n\`;
            patterns.forEach(pattern => {
                const displayName = pattern.replace(/_/g, ' ').replace(/\\b\\w/g, c => c.toUpperCase());
                message += \`  \${colors.cyan}•\${colors.reset} \${displayName}\\n\`;
            });
            
            message += \`\\n\${colors.blue}Security Features:\${colors.reset}\\n\`;
            message += \`  \${colors.green}✓\${colors.reset} Blocks hardcoded secrets in code\\n\`;
            message += \`  \${colors.green}✓\${colors.reset} Scans user prompts for sensitive data\\n\`;
            message += \`  \${colors.green}✓\${colors.reset} Protects Claude's responses from leaks\\n\`;
            message += \`  \${colors.green}✓\${colors.reset} Monitors file operations and commands\\n\`;
            
            message += \`\\n\${colors.dim}Tip: Use environment variables instead of hardcoded secrets\${colors.reset}\\n\`;
            message += \`\${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${colors.reset}\\n\`;
            
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
        console.log(\`\${colors.cyan}🛡️ Guardian Security Active\${colors.reset}\`);
        console.log(\`\${colors.green}Your session is protected against secret exposure\${colors.reset}\\n\`);
        process.exit(0);
    }
}

if (require.main === module) {
    main();
}
`;

// Create the session hook file
try {
    fs.writeFileSync(SESSION_HOOK_FILE, sessionHookContent);
    fs.chmodSync(SESSION_HOOK_FILE, 0o755);
    console.log('✅ Session start hook created successfully');
    process.exit(0);
} catch (error) {
    console.error('❌ Failed to create session start hook:', error.message);
    process.exit(1);
}