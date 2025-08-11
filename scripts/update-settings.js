#!/usr/bin/env node

/**
 * Updates Claude settings.json to add Guardian hooks
 * Used by the installer to configure hook integration
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_CONFIG_DIR = path.join(os.homedir(), '.claude');
const SETTINGS_FILE = path.join(CLAUDE_CONFIG_DIR, 'settings.json');
const HOOKS_DIR = path.join(CLAUDE_CONFIG_DIR, 'hooks');

function updateSettings() {
    let settings = {};
    
    // Load existing settings if they exist
    if (fs.existsSync(SETTINGS_FILE)) {
        try {
            settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
        } catch (error) {
            console.error('Error reading existing settings:', error.message);
            process.exit(1);
        }
    }
    
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
            command: path.join(HOOKS_DIR, 'guardian-hook.js'),
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
            command: path.join(HOOKS_DIR, 'guardian-hook.js'),
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
    const sessionHookPath = path.join(HOOKS_DIR, 'session-start-hook.js');
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
    
    // Write updated settings
    try {
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
        console.log('✅ Settings updated successfully');
        process.exit(0);
    } catch (error) {
        console.error('❌ Failed to write settings:', error.message);
        process.exit(1);
    }
}

// Run the update
updateSettings();