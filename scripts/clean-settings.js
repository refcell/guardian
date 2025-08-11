#!/usr/bin/env node

/**
 * Removes Guardian hooks from Claude settings.json
 * Used by the uninstaller to clean up hook integration
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_CONFIG_DIR = path.join(os.homedir(), '.claude');
const SETTINGS_FILE = path.join(CLAUDE_CONFIG_DIR, 'settings.json');

function cleanSettings() {
    if (!fs.existsSync(SETTINGS_FILE)) {
        console.log('No settings file found');
        process.exit(0);
    }
    
    try {
        const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
        
        // Remove guardian hook entries from PreToolUse (array format)
        if (settings.hooks && settings.hooks.PreToolUse) {
            if (Array.isArray(settings.hooks.PreToolUse)) {
                // New array format
                settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    (!h.hooks[0].command.includes('guardian-hook.js') &&
                     !h.hooks[0].command.includes('guardian-wrapper.sh') &&
                     !h.hooks[0].command.includes('secure-command.js'))
                );
                
                if (settings.hooks.PreToolUse.length === 0) {
                    delete settings.hooks.PreToolUse;
                }
            } else {
                // Old object format (for backwards compatibility)
                const toolsToClean = ['Write', 'Edit', 'MultiEdit', 'Bash'];
                toolsToClean.forEach(tool => {
                    if (settings.hooks.PreToolUse[tool] && 
                        (settings.hooks.PreToolUse[tool].includes('guardian-wrapper.sh') ||
                         settings.hooks.PreToolUse[tool].includes('guardian-hook.js') ||
                         settings.hooks.PreToolUse[tool].includes('secure-command.js'))) {
                        delete settings.hooks.PreToolUse[tool];
                    }
                });
                
                if (Object.keys(settings.hooks.PreToolUse).length === 0) {
                    delete settings.hooks.PreToolUse;
                }
            }
        }
        
        // Remove guardian hook entries from Stop event
        if (settings.hooks && settings.hooks.Stop) {
            if (Array.isArray(settings.hooks.Stop)) {
                settings.hooks.Stop = settings.hooks.Stop.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    (!h.hooks[0].command.includes('guardian-hook.js') &&
                     !h.hooks[0].command.includes('guardian-wrapper.sh') &&
                     !h.hooks[0].command.includes('secure-command.js'))
                );
                
                if (settings.hooks.Stop.length === 0) {
                    delete settings.hooks.Stop;
                }
            }
        }
        
        // Remove guardian hook entries from SessionStart event
        if (settings.hooks && settings.hooks.SessionStart) {
            if (Array.isArray(settings.hooks.SessionStart)) {
                settings.hooks.SessionStart = settings.hooks.SessionStart.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    !h.hooks[0].command.includes('session-start-hook.js')
                );
                
                if (settings.hooks.SessionStart.length === 0) {
                    delete settings.hooks.SessionStart;
                }
            }
        }
        
        // Remove guardian hook entries from UserPromptSubmit event
        if (settings.hooks && settings.hooks.UserPromptSubmit) {
            if (Array.isArray(settings.hooks.UserPromptSubmit)) {
                settings.hooks.UserPromptSubmit = settings.hooks.UserPromptSubmit.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    !h.hooks[0].command.includes('guardian-hook.js')
                );
                
                if (settings.hooks.UserPromptSubmit.length === 0) {
                    delete settings.hooks.UserPromptSubmit;
                }
            }
        }
        
        // Remove guardian hook entries from SubagentStop event
        if (settings.hooks && settings.hooks.SubagentStop) {
            if (Array.isArray(settings.hooks.SubagentStop)) {
                settings.hooks.SubagentStop = settings.hooks.SubagentStop.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    !h.hooks[0].command.includes('guardian-hook.js')
                );
                
                if (settings.hooks.SubagentStop.length === 0) {
                    delete settings.hooks.SubagentStop;
                }
            }
        }
        
        // Remove guardian hook entries from PostToolUse event (if debug was enabled)
        if (settings.hooks && settings.hooks.PostToolUse) {
            if (Array.isArray(settings.hooks.PostToolUse)) {
                settings.hooks.PostToolUse = settings.hooks.PostToolUse.filter(h => 
                    !h.hooks || !h.hooks[0] || !h.hooks[0].command || 
                    !h.hooks[0].command.includes('guardian-hook.js')
                );
                
                if (settings.hooks.PostToolUse.length === 0) {
                    delete settings.hooks.PostToolUse;
                }
            }
        }
        
        // Remove empty hooks object
        if (settings.hooks && Object.keys(settings.hooks).length === 0) {
            delete settings.hooks;
        }
        
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
        console.log('✅ Settings updated');
        process.exit(0);
    } catch (error) {
        console.error('⚠️  Could not update settings.json automatically');
        console.error('   Please manually remove hook entries from:', SETTINGS_FILE);
        process.exit(1);
    }
}

// Run the cleanup
cleanSettings();