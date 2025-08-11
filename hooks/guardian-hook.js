#!/usr/bin/env node

/**
 * Guardian Hook for Claude Code
 * 
 * This hook integrates with Claude Code's hook system to scan for secrets
 * in tool inputs before they are executed.
 * 
 * Claude Code sends JSON data to stdin with the following structure:
 * {
 *   "toolName": "Write|Edit|Bash|etc",
 *   "toolInput": { ... tool specific parameters ... }
 * }
 */

const fs = require('fs');
const path = require('path');

// Load agent configuration
const agentConfig = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'secrets-guardian.json'), 'utf8')
);

class SecretsGuardian {
  constructor() {
    this.patterns = this.compilePatterns(agentConfig.patterns);
  }

  compilePatterns(patternGroups) {
    const compiled = {};
    for (const [category, patterns] of Object.entries(patternGroups)) {
      compiled[category] = patterns.map(pattern => new RegExp(pattern, 'gmi'));
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
    const contentStr = typeof content === 'object' ? JSON.stringify(content) : String(content);

    for (const [category, patterns] of Object.entries(this.patterns)) {
      for (const pattern of patterns) {
        pattern.lastIndex = 0; // Reset regex state
        const matches = contentStr.matchAll(pattern);
        for (const match of matches) {
          const secret = {
            type: category,
            match: match[0].substring(0, 50) + '...',
            line: this.getLineNumber(contentStr, match.index),
            position: match.index
          };
          
          results.secrets_found.push(secret);
          results.status = 'danger';
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
    }

    return results;
  }

  getLineNumber(content, index) {
    const lines = content.substring(0, index).split('\n');
    return lines.length;
  }
}

function processClaudeHookInput(input) {
  const guardian = new SecretsGuardian();
  
  try {
    const data = JSON.parse(input);
    const { toolName, toolInput } = data;
    
    // Extract content to scan based on tool type
    let contentToScan = '';
    
    switch (toolName) {
      case 'Write':
        contentToScan = toolInput.content || '';
        break;
      case 'Edit':
      case 'MultiEdit':
        if (toolInput.new_string) {
          contentToScan = toolInput.new_string;
        } else if (toolInput.edits) {
          // For MultiEdit, scan all new_string values
          contentToScan = toolInput.edits.map(e => e.new_string || '').join('\n');
        }
        break;
      case 'Bash':
        contentToScan = toolInput.command || '';
        break;
      default:
        // For other tools, scan the entire input
        contentToScan = JSON.stringify(toolInput);
    }
    
    const result = guardian.scanContent(contentToScan);
    
    if (result.blocked) {
      // Format error message for Claude Code
      console.error(JSON.stringify({
        error: 'Security violation: Secrets detected',
        details: result.secrets_found.map(s => `${s.type}: ${s.match}`).join('\n'),
        recommendations: result.recommendations
      }, null, 2));
      process.exit(1);
    }
    
    // If safe, exit quietly
    process.exit(0);
    
  } catch (error) {
    // Log error but don't block on parsing errors
    console.error(JSON.stringify({
      error: 'Hook error',
      message: error.message
    }, null, 2));
    // Exit 0 to not block on errors
    process.exit(0);
  }
}

// Main entry point
function main() {
  let input = '';
  
  process.stdin.setEncoding('utf8');
  
  process.stdin.on('data', (chunk) => {
    input += chunk;
  });
  
  process.stdin.on('end', () => {
    processClaudeHookInput(input);
  });
  
  // Handle timeout (Claude Code has 60 second timeout)
  setTimeout(() => {
    console.error(JSON.stringify({
      error: 'Hook timeout',
      message: 'Guardian hook timed out after 30 seconds'
    }));
    process.exit(0);
  }, 30000);
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { SecretsGuardian };