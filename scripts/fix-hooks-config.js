#!/usr/bin/env node

/**
 * Fix Guardian hooks configuration to ensure they trigger properly
 * Uses wildcard matchers and correct field names
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_CONFIG_DIR = path.join(os.homedir(), '.claude');
const SETTINGS_FILE = path.join(CLAUDE_CONFIG_DIR, 'settings.json');
const HOOKS_DIR = path.join(CLAUDE_CONFIG_DIR, 'hooks');

console.log('Fixing Guardian hooks configuration...\n');

// Load current settings
let settings = {};
if (fs.existsSync(SETTINGS_FILE)) {
    try {
        settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
        console.log('✅ Loaded existing settings.json');
    } catch (e) {
        console.error('Error parsing settings:', e.message);
        settings = {};
    }
} else {
    console.log('Creating new settings.json');
}

// Initialize hooks
if (!settings.hooks) {
    settings.hooks = {};
}

// Clear existing Guardian hooks to start fresh
const hookTypes = ['PreToolUse', 'PostToolUse', 'UserPromptSubmit', 'Stop', 'SubagentStop', 'SessionStart'];
hookTypes.forEach(type => {
    if (settings.hooks[type]) {
        settings.hooks[type] = settings.hooks[type].filter(config => {
            if (!config.hooks || !Array.isArray(config.hooks)) return true;
            return !config.hooks.some(h => 
                h.command && (h.command.includes('guardian-hook') || h.command.includes('session-start-hook'))
            );
        });
        if (settings.hooks[type].length === 0) {
            delete settings.hooks[type];
        }
    }
});

// Get absolute paths
const guardianHook = path.join(HOOKS_DIR, 'guardian-hook.js');
const sessionHook = path.join(HOOKS_DIR, 'session-start-hook.js');

// Configure PreToolUse with wildcard matcher for ALL tools
if (!settings.hooks.PreToolUse) {
    settings.hooks.PreToolUse = [];
}
settings.hooks.PreToolUse.push({
    matcher: '.*',  // Match ALL tools with regex wildcard
    hooks: [{
        type: 'command',
        command: guardianHook,
        timeout: 30
    }]
});
console.log('  ✅ PreToolUse: Configured for ALL tools with .* matcher');

// Configure Stop hook with wildcard
if (!settings.hooks.Stop) {
    settings.hooks.Stop = [];
}
settings.hooks.Stop.push({
    matcher: '.*',  // Match all Stop events
    hooks: [{
        type: 'command',
        command: guardianHook,
        timeout: 30
    }]
});
console.log('  ✅ Stop: Configured for all events with .* matcher');

// Configure UserPromptSubmit with wildcard
if (!settings.hooks.UserPromptSubmit) {
    settings.hooks.UserPromptSubmit = [];
}
settings.hooks.UserPromptSubmit.push({
    matcher: '.*',
    hooks: [{
        type: 'command',
        command: guardianHook,
        timeout: 30
    }]
});
console.log('  ✅ UserPromptSubmit: Configured with .* matcher');

// Configure SubagentStop
if (!settings.hooks.SubagentStop) {
    settings.hooks.SubagentStop = [];
}
settings.hooks.SubagentStop.push({
    matcher: '.*',
    hooks: [{
        type: 'command',
        command: guardianHook,
        timeout: 30
    }]
});
console.log('  ✅ SubagentStop: Configured with .* matcher');

// Configure SessionStart for all types
if (!settings.hooks.SessionStart) {
    settings.hooks.SessionStart = [];
}
['startup', 'resume', 'clear'].forEach(matcher => {
    settings.hooks.SessionStart.push({
        matcher: matcher,
        hooks: [{
            type: 'command',
            command: sessionHook,
            timeout: 10
        }]
    });
});
console.log('  ✅ SessionStart: Configured for startup, resume, clear');

// Add PostToolUse for debugging if GUARDIAN_DEBUG is set
if (process.env.GUARDIAN_DEBUG === 'true') {
    if (!settings.hooks.PostToolUse) {
        settings.hooks.PostToolUse = [];
    }
    settings.hooks.PostToolUse.push({
        matcher: '.*',
        hooks: [{
            type: 'command',
            command: guardianHook,
            timeout: 30
        }]
    });
    console.log('  ✅ PostToolUse: Configured for debugging');
}

// Write updated settings
try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
    console.log('\n✅ Successfully updated settings.json');
} catch (e) {
    console.error('Failed to write settings:', e.message);
    process.exit(1);
}

// Display summary
console.log('\n📋 Hook Configuration Summary:');
console.log('  • PreToolUse: Wildcard matcher (.*) for ALL tools');
console.log('  • Stop: Wildcard matcher (.*) for all responses');
console.log('  • UserPromptSubmit: Scans all user inputs');
console.log('  • SubagentStop: Monitors subagent outputs');
console.log('  • SessionStart: Security scan on startup/resume/clear');

console.log('\n🔍 Verification:');
console.log(`  Guardian hook: ${fs.existsSync(guardianHook) ? '✅ Found' : '❌ Missing'}`);
console.log(`  Session hook: ${fs.existsSync(sessionHook) ? '✅ Found' : '❌ Missing'}`);
console.log(`  Config file: ${fs.existsSync(path.join(HOOKS_DIR, 'secrets-guardian.json')) ? '✅ Found' : '❌ Missing'}`);

console.log('\n⚠️  IMPORTANT: Restart Claude Code for changes to take effect!');
console.log('\n🧪 Test the hooks by trying to write a secret:');
console.log('  Ask Claude: "Create test.txt with AWS_ACCESS_KEY_ID=AKIA..."');