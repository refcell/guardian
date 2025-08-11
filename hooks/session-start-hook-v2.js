#!/usr/bin/env node

/**
 * SessionStart Hook v2 for Guardian
 * 
 * Scans environment and working directory for exposed secrets when sessions start.
 * Displays security status and warnings about any detected issues.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

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

class SecretsScanner {
    constructor() {
        this.patterns = this.loadPatterns();
    }

    loadPatterns() {
        try {
            const config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
            const compiled = {};
            for (const [category, patterns] of Object.entries(config.patterns || {})) {
                compiled[category] = patterns.map(pattern => {
                    try {
                        return new RegExp(pattern, 'gmi');
                    } catch (e) {
                        debugLog(`Failed to compile pattern in ${category}: ${pattern}`);
                        return null;
                    }
                }).filter(p => p !== null);
            }
            return compiled;
        } catch (e) {
            debugLog(`Error loading patterns: ${e.message}`);
            // Fallback patterns
            return {
                aws_credentials: [/AKIA[0-9A-Z]{16}/gi],
                api_keys: [/sk-[a-zA-Z0-9]{48}/gi],
                github_tokens: [/ghp_[a-zA-Z0-9]{36}/gi]
            };
        }
    }

    scanContent(content) {
        const findings = [];
        const contentStr = String(content);
        
        for (const [category, patterns] of Object.entries(this.patterns)) {
            for (const pattern of patterns) {
                pattern.lastIndex = 0;
                const matches = [...contentStr.matchAll(pattern)];
                for (const match of matches) {
                    findings.push({
                        type: category,
                        match: match[0].substring(0, 30) + (match[0].length > 30 ? '...' : ''),
                        position: match.index
                    });
                }
            }
        }
        
        return findings;
    }

    scanEnvironment() {
        const warnings = [];
        const sensitiveEnvVars = [
            'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY',
            'GITHUB_TOKEN', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY',
            'DATABASE_URL', 'API_KEY', 'SECRET_KEY', 'PRIVATE_KEY'
        ];
        
        for (const envVar of sensitiveEnvVars) {
            if (process.env[envVar]) {
                const value = process.env[envVar];
                // Check if it looks like a real secret (not a placeholder)
                if (value && !value.includes('${') && !value.includes('$(') && 
                    value.length > 10 && !/^[*x]+$/i.test(value)) {
                    warnings.push({
                        type: 'environment',
                        variable: envVar,
                        preview: value.substring(0, 8) + '...'
                    });
                }
            }
        }
        
        return warnings;
    }

    scanWorkingDirectory() {
        const warnings = [];
        const cwd = process.cwd();
        
        try {
            // Check for common secret files
            const secretFiles = [
                '.env', '.env.local', '.env.production',
                'credentials', 'secrets.json', 'config.json',
                '.aws/credentials', '.ssh/id_rsa'
            ];
            
            for (const file of secretFiles) {
                const filePath = path.join(cwd, file);
                if (fs.existsSync(filePath)) {
                    try {
                        const stats = fs.statSync(filePath);
                        if (stats.isFile() && stats.size > 0) {
                            // Read first 1000 bytes to check for secrets
                            const content = fs.readFileSync(filePath, { encoding: 'utf8', flag: 'r' })
                                .substring(0, 1000);
                            const findings = this.scanContent(content);
                            if (findings.length > 0) {
                                warnings.push({
                                    type: 'file',
                                    path: file,
                                    secrets: findings.length,
                                    types: [...new Set(findings.map(f => f.type))]
                                });
                            }
                        }
                    } catch (e) {
                        debugLog(`Error scanning ${file}: ${e.message}`);
                    }
                }
            }
            
            // Check git status for untracked secret files
            try {
                const gitStatus = execSync('git status --porcelain 2>/dev/null', { 
                    cwd, 
                    encoding: 'utf8',
                    timeout: 2000 
                });
                
                const untrackedSecretFiles = gitStatus.split('\n')
                    .filter(line => line.startsWith('??'))
                    .map(line => line.substring(3).trim())
                    .filter(file => 
                        file.includes('.env') || 
                        file.includes('secret') || 
                        file.includes('credential') ||
                        file.includes('key')
                    );
                
                if (untrackedSecretFiles.length > 0) {
                    warnings.push({
                        type: 'git',
                        message: `${untrackedSecretFiles.length} untracked files may contain secrets`,
                        files: untrackedSecretFiles.slice(0, 3)
                    });
                }
            } catch (e) {
                // Not a git repo or git not available
            }
            
        } catch (e) {
            debugLog(`Error scanning working directory: ${e.message}`);
        }
        
        return warnings;
    }
}

function formatSecurityReport(sessionType, envWarnings, fileWarnings) {
    const icon = '🛡️';
    let message = `\n${colors.cyan}${colors.bright}${icon} Guardian Security Check${colors.reset}\n`;
    message += `${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n\n`;
    
    // Session type message
    if (sessionType === 'new') {
        message += `${colors.green}Starting new session with security protection${colors.reset}\n`;
    } else if (sessionType === 'resumed') {
        message += `${colors.green}Resuming session with security protection${colors.reset}\n`;
    } else if (sessionType === 'cleared') {
        message += `${colors.green}Session cleared with security protection${colors.reset}\n`;
    }
    
    // Security scan results
    const totalWarnings = envWarnings.length + fileWarnings.length;
    
    if (totalWarnings === 0) {
        message += `${colors.green}✓ No exposed secrets detected${colors.reset}\n\n`;
    } else {
        message += `\n${colors.red}${colors.bright}⚠️  Security Warnings (${totalWarnings} issues)${colors.reset}\n\n`;
        
        // Environment warnings
        if (envWarnings.length > 0) {
            message += `${colors.yellow}Environment Variables:${colors.reset}\n`;
            envWarnings.forEach(w => {
                message += `  ${colors.red}•${colors.reset} ${w.variable} = ${w.preview}\n`;
            });
            message += `\n`;
        }
        
        // File warnings
        if (fileWarnings.length > 0) {
            message += `${colors.yellow}Files with Secrets:${colors.reset}\n`;
            fileWarnings.forEach(w => {
                if (w.type === 'file') {
                    message += `  ${colors.red}•${colors.reset} ${w.path}: ${w.secrets} secret(s) [${w.types.join(', ')}]\n`;
                } else if (w.type === 'git') {
                    message += `  ${colors.red}•${colors.reset} ${w.message}\n`;
                    w.files.forEach(f => {
                        message += `    - ${f}\n`;
                    });
                }
            });
            message += `\n`;
        }
        
        message += `${colors.yellow}${colors.bright}Recommendations:${colors.reset}\n`;
        message += `  1. Remove hardcoded secrets from files\n`;
        message += `  2. Add secret files to .gitignore\n`;
        message += `  3. Use environment variables or secret managers\n`;
        message += `  4. Clear sensitive environment variables\n\n`;
    }
    
    // Active protection features
    message += `${colors.blue}Active Protection:${colors.reset}\n`;
    message += `  ${colors.green}✓${colors.reset} Blocking writes with secrets\n`;
    message += `  ${colors.green}✓${colors.reset} Scanning commands before execution\n`;
    message += `  ${colors.green}✓${colors.reset} Filtering Claude's responses\n`;
    message += `  ${colors.green}✓${colors.reset} Monitoring file operations\n`;
    
    message += `\n${colors.dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`;
    
    return message;
}

function processSessionStart(input) {
    try {
        const data = typeof input === 'string' ? JSON.parse(input) : input;
        debugLog(`SessionStart event received: ${JSON.stringify(Object.keys(data))}`);
        
        // Get session type
        const source = data.source || data.matcher || 'startup';
        let sessionType = 'new';
        if (source === 'resume') sessionType = 'resumed';
        if (source === 'clear') sessionType = 'cleared';
        
        // Perform security scans
        const scanner = new SecretsScanner();
        const envWarnings = scanner.scanEnvironment();
        const fileWarnings = scanner.scanWorkingDirectory();
        
        debugLog(`Found ${envWarnings.length} env warnings, ${fileWarnings.length} file warnings`);
        
        // Format and display report
        const message = formatSecurityReport(sessionType, envWarnings, fileWarnings);
        console.log(message);
        
        // Exit with appropriate code
        // Exit 0 to not block, but we've shown warnings
        process.exit(0);
        
    } catch (error) {
        debugLog(`Error processing SessionStart: ${error.message}`);
        
        // Fallback message
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}`);
        console.log(`${colors.green}Session protected against secret exposure${colors.reset}\n`);
        process.exit(0);
    }
}

// Main entry point
function main() {
    debugLog('SessionStart security scan initiated');
    
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
            processSessionStart({ source: 'startup' });
        }
    });
    
    process.stdin.on('error', (error) => {
        debugLog(`Stdin error: ${error.message}`);
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}\n`);
        process.exit(0);
    });
    
    // Timeout protection (3 seconds for scanning)
    setTimeout(() => {
        debugLog('SessionStart scan timeout');
        console.log(`${colors.cyan}🛡️ Guardian Security Active${colors.reset}\n`);
        process.exit(0);
    }, 3000);
}

if (require.main === module) {
    main();
}

module.exports = { processSessionStart };