#!/usr/bin/env node

/**
 * Configure Claude Code hooks for Guardian
 * This script properly sets up all hook types in settings.json
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_CONFIG_DIR = path.join(os.homedir(), '.claude');
const SETTINGS_FILE = path.join(CLAUDE_CONFIG_DIR, 'settings.json');
const HOOKS_DIR = path.join(CLAUDE_CONFIG_DIR, 'hooks');
const HOOK_SCRIPT = path.join(HOOKS_DIR, 'guardian-hook.js');

console.log('Configuring Guardian hooks for Claude Code...\n');

// Load or create settings
let settings = {};
if (fs.existsSync(SETTINGS_FILE)) {
    try {
        const content = fs.readFileSync(SETTINGS_FILE, 'utf8');
        settings = JSON.parse(content);
        console.log('✅ Loaded existing settings.json');
    } catch (e) {
        console.error('⚠️  Error parsing existing settings:', e.message);
        settings = {};
    }
} else {
    console.log('📝 Creating new settings.json');
}

// Initialize hooks section
if (!settings.hooks) {
    settings.hooks = {};
}

// Helper to configure a hook
function configureHook(eventName, matcher, description) {
    if (!settings.hooks[eventName]) {
        settings.hooks[eventName] = [];
    }
    
    // Remove existing guardian hooks for this event
    settings.hooks[eventName] = settings.hooks[eventName].filter(config => {
        if (!config.hooks || !Array.isArray(config.hooks)) return true;
        return !config.hooks.some(h => 
            h.command && h.command.includes('guardian-hook')
        );
    });
    
    // Add new configuration with absolute path
    const hookConfig = {
        matcher: matcher,
        hooks: [{
            type: 'command',
            command: HOOK_SCRIPT,
            timeout: 60
        }]
    };
    
    settings.hooks[eventName].push(hookConfig);
    console.log(`  ✅ ${eventName}: ${description}`);
}

console.log('\nConfiguring hooks:');

// Configure all hook types
configureHook('PreToolUse', 'Write|Edit|MultiEdit|Bash|Task', 'Scan before Write, Edit, MultiEdit, Bash, Task');
configureHook('UserPromptSubmit', '.*', 'Scan all user prompts');
configureHook('Stop', '.*', 'Scan all Claude responses');
configureHook('SubagentStop', '.*', 'Scan all subagent responses');

// Configure SessionStart hooks for all session types
if (!settings.hooks.SessionStart) {
    settings.hooks.SessionStart = [];
}

// Remove existing guardian session hooks
settings.hooks.SessionStart = settings.hooks.SessionStart.filter(config => {
    if (!config.hooks || !Array.isArray(config.hooks)) return true;
    return !config.hooks.some(h => 
        h.command && h.command.includes('session-start-hook')
    );
});

// Add session start hooks for different matchers
const sessionStartScript = path.join(HOOKS_DIR, 'session-start-hook.js');
['startup', 'resume', 'clear'].forEach(matcher => {
    settings.hooks.SessionStart.push({
        matcher: matcher,
        hooks: [{
            type: 'command',
            command: sessionStartScript,
            timeout: 10
        }]
    });
});
console.log('  ✅ SessionStart: Display security status on startup, resume, clear');

// Optional: PostToolUse for debugging
if (process.env.GUARDIAN_DEBUG === 'true') {
    configureHook('PostToolUse', 'Write|Edit|MultiEdit|Bash', 'Log tool usage (debug mode)');
}

// Write updated settings
try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
    console.log('\n✅ Successfully updated settings.json');
} catch (e) {
    console.error('\n❌ Failed to write settings.json:', e.message);
    process.exit(1);
}

// Verify the configuration
console.log('\nVerifying configuration:');
console.log(`  Hook script: ${fs.existsSync(HOOK_SCRIPT) ? '✅ Found' : '❌ Not found'}`);
console.log(`  Session hook: ${fs.existsSync(sessionStartScript) ? '✅ Found' : '❌ Not found'}`);
console.log(`  Config file: ${fs.existsSync(path.join(HOOKS_DIR, 'secrets-guardian.json')) ? '✅ Found' : '❌ Not found'}`);
console.log(`  Settings: ${SETTINGS_FILE}`);

console.log('\n📋 Summary:');
console.log('  The Guardian hook is now configured to:');
console.log('  • Show security status when sessions start/resume/clear');
console.log('  • Block secrets in Write, Edit, MultiEdit, Bash, and Task operations');
console.log('  • Scan user prompts before processing');
console.log('  • Scan Claude\'s responses before displaying');
console.log('  • Scan subagent outputs');

if (process.env.GUARDIAN_DEBUG === 'true') {
    console.log('  • Log all tool usage (debug mode enabled)');
    console.log(`  • Debug log: ${path.join(CLAUDE_CONFIG_DIR, 'guardian-debug.log')}`);
}

console.log('\n🎉 Configuration complete!');
console.log('  Restart Claude Code for changes to take effect.');