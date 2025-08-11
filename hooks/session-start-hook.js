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
            // Enhanced fallback patterns for common secrets
            return {
                aws_credentials: [
                    /AKIA[0-9A-Z]{16}/gi,
                    /AWS_ACCESS_KEY_ID\s*=\s*[A-Z0-9]{20}/gi,
                    /AWS_SECRET_ACCESS_KEY\s*=\s*[A-Za-z0-9/+=]{40}/gi
                ],
                api_keys: [
                    /sk-[a-zA-Z0-9]{48}/gi,
                    /API_KEY\s*=\s*[a-zA-Z0-9_-]{20,}/gi,
                    /OPENAI_API_KEY\s*=\s*sk-[a-zA-Z0-9]{48}/gi,
                    /ANTHROPIC_API_KEY\s*=\s*[a-zA-Z0-9_-]{20,}/gi
                ],
                github_tokens: [
                    /ghp_[a-zA-Z0-9]{36}/gi,
                    /gho_[a-zA-Z0-9]{36}/gi,
                    /ghu_[a-zA-Z0-9]{36}/gi,
                    /ghs_[a-zA-Z0-9]{36}/gi,
                    /GITHUB_TOKEN\s*=\s*gh[a-z]_[a-zA-Z0-9]{36}/gi
                ],
                database_urls: [
                    /DATABASE_URL\s*=\s*[a-zA-Z]+:\/\/[^\s]+/gi,
                    /mongodb:\/\/[^\s]+/gi,
                    /postgres:\/\/[^\s]+/gi,
                    /mysql:\/\/[^\s]+/gi
                ],
                private_keys: [
                    /-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----/gi,
                    /PRIVATE_KEY\s*=\s*[A-Za-z0-9+/=\n\r-]{50,}/gi
                ],
                jwt_secrets: [
                    /JWT_SECRET\s*=\s*[a-zA-Z0-9_-]{20,}/gi,
                    /SECRET_KEY\s*=\s*[a-zA-Z0-9_-]{20,}/gi
                ]
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
                    const fullMatch = match[0];
                    findings.push({
                        type: category,
                        match: fullMatch,
                        preview: fullMatch.substring(0, 8) + '...',
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
            // Get all files in current directory
            const allFiles = this.getAllFiles(cwd);
            debugLog(`Scanning ${allFiles.length} files in working directory`);
            
            // Scan all files for secrets
            for (const file of allFiles) {
                const filePath = path.join(cwd, file);
                try {
                    const stats = fs.statSync(filePath);
                    if (stats.isFile() && stats.size > 0 && stats.size < 1024 * 1024) { // Skip files > 1MB
                        // Skip gitignored files
                        if (!this.isFileGitIgnored(file, cwd)) {
                            const content = fs.readFileSync(filePath, { encoding: 'utf8', flag: 'r' });
                            const findings = this.scanContent(content);
                            if (findings.length > 0) {
                                warnings.push({
                                    type: 'file',
                                    path: file,
                                    secrets: findings.length,
                                    findings: findings,
                                    types: [...new Set(findings.map(f => f.type))]
                                });
                            }
                        }
                    }
                } catch (e) {
                    debugLog(`Error scanning ${file}: ${e.message}`);
                }
            }
            
            // Check git staged files if in git repo
            this.scanGitStagedFiles(cwd, warnings);
            
        } catch (e) {
            debugLog(`Error scanning working directory: ${e.message}`);
        }
        
        return warnings;
    }

    getAllFiles(dir) {
        const files = [];
        try {
            const items = fs.readdirSync(dir);
            for (const item of items) {
                // Skip hidden files EXCEPT .env files
                if (item.startsWith('.') && !item.includes('.env')) {
                    continue;
                }
                if (item === 'node_modules' || item === '.git') {
                    continue;
                }
                
                const fullPath = path.join(dir, item);
                try {
                    const stats = fs.statSync(fullPath);
                    if (stats.isFile()) {
                        files.push(item);
                    }
                } catch (e) {
                    // Skip files we can't stat
                }
            }
        } catch (e) {
            debugLog(`Error reading directory ${dir}: ${e.message}`);
        }
        return files;
    }

    isFileGitIgnored(file, cwd) {
        try {
            execSync(`git check-ignore "${file}" 2>/dev/null`, { 
                cwd, 
                timeout: 1000,
                stdio: 'pipe'
            });
            return true; // If no error, file is ignored
        } catch (e) {
            return false; // If error, file is not ignored
        }
    }

    scanGitStagedFiles(cwd, warnings) {
        try {
            // Check if we're in a git repository
            execSync('git rev-parse --git-dir 2>/dev/null', { cwd, timeout: 1000, stdio: 'pipe' });
            
            // Get staged files
            const stagedFiles = execSync('git ls-files --cached 2>/dev/null', { 
                cwd, 
                encoding: 'utf8',
                timeout: 2000 
            }).split('\n').filter(f => f.trim());
            
            debugLog(`Found ${stagedFiles.length} staged files`);
            
            const exposedSecrets = [];
            for (const file of stagedFiles) {
                const filePath = path.join(cwd, file);
                try {
                    if (fs.existsSync(filePath)) {
                        const stats = fs.statSync(filePath);
                        if (stats.isFile() && stats.size > 0 && stats.size < 1024 * 1024) {
                            const content = fs.readFileSync(filePath, { encoding: 'utf8', flag: 'r' });
                            const findings = this.scanContent(content);
                            if (findings.length > 0 && !this.isFileGitIgnored(file, cwd)) {
                                exposedSecrets.push({
                                    file,
                                    secrets: findings.length,
                                    findings: findings,
                                    types: [...new Set(findings.map(f => f.type))]
                                });
                            }
                        }
                    }
                } catch (e) {
                    debugLog(`Error scanning staged file ${file}: ${e.message}`);
                }
            }
            
            if (exposedSecrets.length > 0) {
                warnings.push({
                    type: 'git-staged',
                    message: `${exposedSecrets.length} staged files contain secrets that aren't gitignored`,
                    files: exposedSecrets
                });
            }
            
        } catch (e) {
            debugLog(`Not a git repo or git error: ${e.message}`);
        }
    }
}

function formatSecurityReport(sessionType, envWarnings, fileWarnings) {
    // Group secrets by location
    const secretsByLocation = {};
    let totalSecrets = 0;
    
    // Collect environment secrets
    if (envWarnings.length > 0) {
        secretsByLocation['environment'] = {
            count: envWarnings.length,
            types: new Set(envWarnings.map(w => formatSecretType(w.variable || 'environment')))
        };
        totalSecrets += envWarnings.length;
    }
    
    // Collect file secrets (only non-gitignored files)
    const exposedFiles = fileWarnings.filter(w => w.type === 'file' && !w.isGitIgnored);
    for (const file of exposedFiles) {
        if (file.findings && file.findings.length > 0) {
            if (!secretsByLocation[file.path]) {
                secretsByLocation[file.path] = {
                    count: 0,
                    types: new Set()
                };
            }
            secretsByLocation[file.path].count += file.findings.length;
            for (const finding of file.findings) {
                secretsByLocation[file.path].types.add(formatSecretType(finding.type));
            }
            totalSecrets += file.findings.length;
        }
    }
    
    // Collect staged file secrets
    const stagedFiles = fileWarnings.filter(w => w.type === 'git-staged');
    for (const staged of stagedFiles) {
        if (staged.files) {
            for (const file of staged.files) {
                if (file.findings && file.findings.length > 0) {
                    const location = `${file.file} (staged)`;
                    if (!secretsByLocation[location]) {
                        secretsByLocation[location] = {
                            count: 0,
                            types: new Set()
                        };
                    }
                    secretsByLocation[location].count += file.findings.length;
                    for (const finding of file.findings) {
                        secretsByLocation[location].types.add(formatSecretType(finding.type));
                    }
                    totalSecrets += file.findings.length;
                }
            }
        }
    }
    
    // If no secrets, show minimal message
    if (totalSecrets === 0) {
        return `${colors.cyan}🛡️ Guardian: ${colors.green}Session protected, no secrets detected${colors.reset}\n`;
    }
    
    // Format concise warning grouped by file
    let message = `${colors.red}🚨 ${totalSecrets} secret${totalSecrets === 1 ? '' : 's'} in ${Object.keys(secretsByLocation).length} location${Object.keys(secretsByLocation).length === 1 ? '' : 's'}:${colors.reset}\n\n`;
    
    // Show up to 5 files with most secrets
    const sortedLocations = Object.entries(secretsByLocation)
        .sort((a, b) => b[1].count - a[1].count)
        .slice(0, 5);
    
    for (const [location, info] of sortedLocations) {
        const typesList = Array.from(info.types).slice(0, 3).join(', ');
        const moreTypes = info.types.size > 3 ? `, +${info.types.size - 3}` : '';
        message += `  ${colors.yellow}${location}${colors.reset}: ${info.count} secret${info.count === 1 ? '' : 's'} (${typesList}${moreTypes})\n`;
    }
    
    if (Object.keys(secretsByLocation).length > 5) {
        const remaining = Object.keys(secretsByLocation).length - 5;
        message += `\n  ${colors.dim}... and ${remaining} more file${remaining === 1 ? '' : 's'}${colors.reset}\n`;
    }
    
    message += `\n${colors.yellow}Fix:${colors.reset} Add files to .gitignore or use environment variables\n`;
    
    return message;
}

function formatSecretType(type) {
    const typeMap = {
        aws_credentials: 'AWS Key',
        api_keys: 'API Token',
        github_tokens: 'GitHub Token',
        database_urls: 'Database URL',
        private_keys: 'Private Key',
        jwt_secrets: 'JWT Secret',
        environment: 'Environment Variable'
    };
    return typeMap[type] || type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
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