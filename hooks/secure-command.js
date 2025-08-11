#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Load agent configuration
const agentConfig = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../agents/secrets-guardian.json'), 'utf8')
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

    for (const [category, patterns] of Object.entries(this.patterns)) {
      for (const pattern of patterns) {
        const matches = content.matchAll(pattern);
        for (const match of matches) {
          const secret = {
            type: category,
            match: match[0].substring(0, 50) + '...',
            line: this.getLineNumber(content, match.index),
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

  scanFile(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      return this.scanContent(content);
    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        secrets_found: [],
        recommendations: [],
        blocked: false
      };
    }
  }

  scanCommand(command) {
    return this.scanContent(command);
  }
}

// Hook entry point
function main() {
  const guardian = new SecretsGuardian();
  
  // Read input from stdin or command line args
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    // Read from stdin for pipe mode
    let input = '';
    process.stdin.setEncoding('utf8');
    
    process.stdin.on('data', (chunk) => {
      input += chunk;
    });
    
    process.stdin.on('end', () => {
      const result = guardian.scanContent(input);
      outputResult(result);
    });
  } else if (args[0] === '--file' && args[1]) {
    // Scan a specific file
    const result = guardian.scanFile(args[1]);
    outputResult(result);
  } else if (args[0] === '--command') {
    // Scan a command
    const command = args.slice(1).join(' ');
    const result = guardian.scanCommand(command);
    outputResult(result);
  } else {
    // Treat all args as content to scan
    const content = args.join(' ');
    const result = guardian.scanContent(content);
    outputResult(result);
  }
}

function outputResult(result) {
  // Output structured JSON response
  console.log(JSON.stringify(result, null, 2));
  
  // Exit with appropriate code
  if (result.blocked) {
    process.exit(1); // Non-zero exit to indicate blocking
  } else {
    process.exit(0);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { SecretsGuardian };