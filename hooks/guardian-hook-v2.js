#!/usr/bin/env node

/**
 * Guardian Hook v2 for Claude Code
 * 
 * Robust implementation with support for multiple hook types and better error handling.
 * Designed to work reliably with Claude Code's hook system.
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

// Debug logging - writes to a log file if DEBUG env var is set
const DEBUG = process.env.GUARDIAN_DEBUG === 'true';
const LOG_FILE = path.join(process.env.HOME, '.claude', 'guardian-debug.log');

function debugLog(message) {
  if (DEBUG) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ${message}\n`;
    try {
      fs.appendFileSync(LOG_FILE, logMessage);
    } catch (e) {
      // Silently fail if can't write log
    }
  }
}

// Load agent configuration
let agentConfig;
try {
  const configPath = path.join(__dirname, 'secrets-guardian.json');
  agentConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  debugLog(`Loaded config from ${configPath}`);
} catch (error) {
  debugLog(`Error loading config: ${error.message}`);
  console.error(JSON.stringify({
    error: 'Configuration error',
    message: 'Failed to load secrets-guardian.json'
  }));
  process.exit(0); // Don't block on config errors
}

class SecretsGuardian {
  constructor() {
    this.patterns = this.compilePatterns(agentConfig.patterns);
    debugLog(`Compiled ${Object.keys(this.patterns).length} pattern categories`);
  }

  compilePatterns(patternGroups) {
    const compiled = {};
    for (const [category, patterns] of Object.entries(patternGroups)) {
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
  }

  scanContent(content) {
    const results = {
      status: 'safe',
      secrets_found: [],
      recommendations: [],
      blocked: false
    };

    // Convert content to string if it's an object
    const contentStr = typeof content === 'object' ? JSON.stringify(content, null, 2) : String(content);
    
    debugLog(`Scanning content of length: ${contentStr.length}`);

    for (const [category, patterns] of Object.entries(this.patterns)) {
      for (const pattern of patterns) {
        pattern.lastIndex = 0; // Reset regex state
        try {
          const matches = [...contentStr.matchAll(pattern)];
          for (const match of matches) {
            const secret = {
              type: category,
              match: match[0].substring(0, 50) + (match[0].length > 50 ? '...' : ''),
              line: this.getLineNumber(contentStr, match.index),
              position: match.index
            };
            
            results.secrets_found.push(secret);
            results.status = 'danger';
            debugLog(`Found secret: ${category} at position ${match.index}`);
          }
        } catch (e) {
          debugLog(`Error scanning with pattern in ${category}: ${e.message}`);
        }
      }
    }

    if (results.secrets_found.length > 0) {
      results.blocked = true;
      results.recommendations = [
        'Remove hardcoded secrets from the code',
        'Use environment variables for sensitive configuration',
        'Consider using a secrets management service',
        'Add the file to .gitignore if it contains secrets'
      ];
      debugLog(`Blocking action: found ${results.secrets_found.length} secrets`);
    }

    return results;
  }

  getLineNumber(content, index) {
    const lines = content.substring(0, index).split('\n');
    return lines.length;
  }
}

/**
 * Process different hook event types
 */
function processHookInput(input) {
  const guardian = new SecretsGuardian();
  
  try {
    const data = typeof input === 'string' ? JSON.parse(input) : input;
    debugLog(`Processing hook event: ${JSON.stringify(Object.keys(data))}`);
    
    let contentToScan = '';
    let eventType = 'unknown';
    
    // Detect event type and extract content to scan
    if (data.tool_name && data.tool_input !== undefined) {
      // PreToolUse/PostToolUse event format
      eventType = 'PreToolUse/PostToolUse';
      const { tool_name, tool_input } = data;
      debugLog(`Tool event: ${tool_name}`);
      
      switch (tool_name) {
        case 'Write':
          contentToScan = tool_input.content || tool_input.file_content || '';
          break;
        case 'Edit':
          contentToScan = tool_input.new_string || tool_input.new_content || '';
          break;
        case 'MultiEdit':
          if (tool_input.edits && Array.isArray(tool_input.edits)) {
            contentToScan = tool_input.edits
              .map(e => e.new_string || e.new_content || '')
              .join('\n');
          } else {
            contentToScan = JSON.stringify(tool_input);
          }
          break;
        case 'Bash':
          contentToScan = tool_input.command || '';
          break;
        case 'Task':
          contentToScan = tool_input.prompt || '';
          break;
        default:
          contentToScan = JSON.stringify(tool_input);
      }
    } else if (data.messages && Array.isArray(data.messages)) {
      // Stop/SubagentStop event format
      eventType = 'Stop/SubagentStop';
      const assistantMessages = data.messages.filter(m => m.role === 'assistant');
      contentToScan = assistantMessages.map(m => {
        if (typeof m.content === 'string') {
          return m.content;
        } else if (Array.isArray(m.content)) {
          return m.content.map(c => c.text || '').join('\n');
        }
        return '';
      }).join('\n');
      debugLog(`Scanning ${assistantMessages.length} assistant messages`);
    } else if (data.prompt) {
      // UserPromptSubmit event format
      eventType = 'UserPromptSubmit';
      contentToScan = data.prompt;
      debugLog(`Scanning user prompt of length ${contentToScan.length}`);
    } else if (data.notification_type) {
      // Notification event
      eventType = 'Notification';
      debugLog(`Notification event: ${data.notification_type}`);
      // Don't scan notifications, just pass through
      process.exit(0);
    } else {
      // Unknown format - scan everything as fallback
      eventType = 'Unknown';
      contentToScan = JSON.stringify(data);
      debugLog(`Unknown event format, scanning full data`);
    }
    
    debugLog(`Event type: ${eventType}, content length: ${contentToScan.length}`);
    
    // Scan the content
    const result = guardian.scanContent(contentToScan);
    
    if (result.blocked) {
      const errorMessage = {
        error: '🛡️ SECURITY ALERT: Secrets Detected',
        event_type: eventType,
        details: result.secrets_found.map(s => 
          `• ${s.type}: "${s.match}" (line ${s.line})`
        ).join('\n'),
        recommendations: result.recommendations.join('\n• '),
        action: 'Operation blocked to prevent secret exposure'
      };
      
      debugLog(`Blocking operation: ${JSON.stringify(errorMessage)}`);
      
      // Output error to stderr and exit with code 2 (blocking error)
      console.error(JSON.stringify(errorMessage, null, 2));
      process.exit(2);
    }
    
    // If safe, exit cleanly
    debugLog('Content is safe, allowing operation');
    process.exit(0);
    
  } catch (error) {
    debugLog(`Error processing input: ${error.message}`);
    // Log error but don't block on parsing errors
    console.error(JSON.stringify({
      error: 'Hook processing error',
      message: error.message,
      stack: DEBUG ? error.stack : undefined
    }, null, 2));
    // Exit 0 to not block on errors
    process.exit(0);
  }
}

/**
 * Main entry point - reads from stdin
 */
function main() {
  debugLog('Guardian hook started');
  
  let input = '';
  
  // Set encoding for stdin
  process.stdin.setEncoding('utf8');
  
  // Read all input from stdin
  process.stdin.on('data', (chunk) => {
    input += chunk;
    debugLog(`Received chunk of size ${chunk.length}`);
  });
  
  // Process when stdin closes
  process.stdin.on('end', () => {
    debugLog(`Total input size: ${input.length}`);
    if (input.trim()) {
      processHookInput(input);
    } else {
      debugLog('No input received, exiting safely');
      process.exit(0);
    }
  });
  
  // Handle errors
  process.stdin.on('error', (error) => {
    debugLog(`Stdin error: ${error.message}`);
    console.error(JSON.stringify({
      error: 'Input error',
      message: error.message
    }));
    process.exit(0);
  });
  
  // Timeout protection (30 seconds)
  const timeout = setTimeout(() => {
    debugLog('Hook timeout after 30 seconds');
    console.error(JSON.stringify({
      error: 'Hook timeout',
      message: 'Guardian hook timed out after 30 seconds'
    }));
    process.exit(0);
  }, 30000);
  
  // Clear timeout if we finish normally
  process.stdin.on('end', () => clearTimeout(timeout));
}

// Run if called directly
if (require.main === module) {
  main();
} else {
  // Export for testing
  module.exports = { SecretsGuardian, processHookInput };
}