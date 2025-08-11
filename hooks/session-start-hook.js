#!/usr/bin/env node

/**
 * SessionStart Hook for Guardian
 * 
 * Displays security reminders and status when a Claude Code session starts.
 * Supports startup, resume, and clear session events.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Configuration
const CLAUDE_CONFIG_DIR = path.join(os.homedir(), '.claude');
const HOOKS_DIR = path.join(CLAUDE_CONFIG_DIR, 'hooks');
const CONFIG_FILE = path.join(HOOKS_DIR, 'secrets-guardian.json');
const DEBUG = process.env.GUARDIAN_DEBUG === 'true';
const LOG_FILE = path.join(CLAUDE_CONFIG_DIR, 'guardian-debug.log');

// Colors for terminal output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m'
};

function debugLog(message) {
    if (DEBUG) {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] [SessionStart] ${message}\n`;
        try {
            fs.appendFileSync(LOG_FILE, logMessage);
        } catch (e) {
            // Silently fail
        }
    }
}

function getSessionType(data) {
    // Determine session type from the event data
    if (data.matcher === 'startup') return 'new';
    if (data.matcher === 'resume') return 'resumed';
    if (data.matcher === 'clear') return 'cleared';
    return 'unknown';
}

function getProtectedPatterns() {
    try {
        const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        const categories = Object.keys(config.patterns || {});
        return categories;
    } catch (e) {
        debugLog(`Error loading patterns: ${e.message}`);
        return ['AWS', 'API Keys', 'Passwords', 'Tokens', 'Private Keys', 'Database'];
    }
}

function formatSecurityMessage(sessionType) {
    const patterns = getProtectedPatterns();
    const icon = '🛡️';
    
    let message = `\n${colors.cyan}${colors.bright}${icon} Guardian Security Active${colors.reset}\n`;
    message += `${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n\n`;
    
    if (sessionType === 'new') {
        message += `${colors.green}Welcome! Your Claude Code session is protected.${colors.reset}\n\n`;
    } else if (sessionType === 'resumed') {
        message += `${colors.green}Session resumed with security protection.${colors.reset}\n\n`;
    } else if (sessionType === 'cleared') {
        message += `${colors.green}Session cleared. Starting fresh with protection.${colors.reset}\n\n`;
    }
    
    message += `${colors.yellow}Protected Secret Types:${colors.reset}\n`;
    patterns.forEach(pattern => {
        message += `  ${colors.cyan}•${colors.reset} ${pattern}\n`;
    });
    
    message += `\n${colors.blue}Security Features:${colors.reset}\n`;
    message += `  ${colors.green}✓${colors.reset} Blocks hardcoded secrets in code\n`;
    message += `  ${colors.green}✓${colors.reset} Scans user prompts for sensitive data\n`;
    message += `  ${colors.green}✓${colors.reset} Protects Claude's responses from leaks\n`;
    message += `  ${colors.green}✓${colors.reset} Monitors file operations and commands\n`;
    
    if (DEBUG) {
        message += `\n${colors.magenta}Debug Mode:${colors.reset} Logging to guardian-debug.log\n`;
    }
    
    message += `\n${colors.dim}Tip: Use environment variables instead of hardcoded secrets${colors.reset}\n`;
    message += `${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`;
    
    return message;
}

function processSessionStart(input) {
    try {
        const data = typeof input === 'string' ? JSON.parse(input) : input;
        debugLog(`SessionStart event received: ${JSON.stringify(data)}`);
        
        const sessionType = getSessionType(data);
        const message = formatSecurityMessage(sessionType);
        
        // Output the security message to stdout
        // This will be displayed in the Claude Code interface
        console.log(message);
        
        // Log session start
        debugLog(`Session ${sessionType} - Security reminder displayed`);
        
        // Check if all required files exist
        const requiredFiles = [
            path.join(HOOKS_DIR, 'guardian-hook.js'),
            CONFIG_FILE
        ];
        
        let allFilesExist = true;
        for (const file of requiredFiles) {
            if (!fs.existsSync(file)) {
                console.error(`${colors.red}⚠️  Warning: Missing file: ${path.basename(file)}${colors.reset}`);
                allFilesExist = false;
            }
        }
        
        if (!allFilesExist) {
            console.error(`${colors.yellow}Run the installer to fix: curl -sSL guardian.refcell.org/install | bash${colors.reset}\n`);
        }
        
        // Success exit
        process.exit(0);
        
    } catch (error) {
        debugLog(`Error processing SessionStart: ${error.message}`);
        
        // Still show a basic message even if there's an error
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}`);
        console.log(`${colors.dim}Your session is protected against secret exposure${colors.reset}\n`);
        
        // Don't block on errors
        process.exit(0);
    }
}

// Main entry point
function main() {
    debugLog('SessionStart hook triggered');
    
    let input = '';
    
    process.stdin.setEncoding('utf8');
    
    process.stdin.on('data', (chunk) => {
        input += chunk;
    });
    
    process.stdin.on('end', () => {
        debugLog(`Input received: ${input.length} bytes`);
        if (input.trim()) {
            processSessionStart(input);
        } else {
            // No input, just show the message anyway
            processSessionStart({ matcher: 'startup' });
        }
    });
    
    process.stdin.on('error', (error) => {
        debugLog(`Stdin error: ${error.message}`);
        // Show basic message on error
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}\n`);
        process.exit(0);
    });
    
    // Timeout protection (5 seconds for session start)
    setTimeout(() => {
        debugLog('SessionStart hook timeout');
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}\n`);
        process.exit(0);
    }, 5000);
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = { processSessionStart };