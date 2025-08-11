# Claude Secrets Guardian 🔒

[![Status](https://img.shields.io/badge/status-active-success.svg)](https://github.com/refcell/guardian)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](./test.sh)
[![Security](https://img.shields.io/badge/security-enabled-blue.svg)](https://github.com/refcell/guardian)

A security hook for Claude Code that prevents accidental exposure of secrets, API keys, passwords, and other sensitive information during AI-assisted coding sessions.

## Quick Start

### Installation

```bash
curl -sSL guardian.refcell.org/install | bash
```

### Test Installation

```bash
curl -sSL guardian.refcell.org/test | bash
```

### Verify Installation

After installation, verify the Guardian is active:

```bash
# Check hook configuration
grep -q "guardian-hook.js" ~/.claude/settings.json && echo "✅ Hooks configured" || echo "❌ Hooks not found"

# Run comprehensive tests
curl -sSL guardian.refcell.org/test | bash
```

### Uninstall

```bash
curl -sSL guardian.refcell.org/uninstall | bash
```

## Features

The Guardian actively monitors and blocks Claude Code operations that may expose sensitive data:

### Protected Operations
- **File Operations**: Blocks writing or editing files containing secrets
- **Command Execution**: Prevents running bash commands with exposed credentials
- **Response Scanning**: Checks Claude's final responses for any leaked secrets
- **Git Protection**: Prevents committing sensitive data to repositories

### Detected Secret Types
- **Cloud Credentials**: AWS keys, Azure credentials, GCP service accounts
- **API Keys**: OpenAI, Anthropic, Stripe, SendGrid, Twilio, etc.
- **Authentication Tokens**: GitHub, GitLab, Slack, Discord tokens
- **Database URLs**: PostgreSQL, MySQL, MongoDB, Redis connection strings
- **Private Keys**: RSA, SSH, PGP private keys
- **Passwords**: Hardcoded passwords and authentication strings
- **JWT Tokens**: JSON Web Tokens with sensitive payloads
- **Webhooks**: Slack, Discord, and other webhook URLs
- **And more**: Continuously updated patterns for emerging secret types

## How It Works

### Architecture
The Guardian integrates with Claude Code's hook system by installing event handlers in `~/.claude/settings.json`:

1. **PreToolUse Hooks**: Intercepts tool operations before execution
   - Scans `Write`, `Edit`, `MultiEdit`, and `Bash` tool inputs
   - Blocks operations containing detected secrets

2. **Stop Hooks**: Analyzes Claude's responses before finalization
   - Ensures no secrets leak into the conversation history
   - Provides an additional layer of protection

### Detection Engine
- Uses regex pattern matching optimized for low latency
- Configurable patterns stored in `~/.claude/hooks/secrets-guardian.json`
- Non-blocking on errors to maintain Claude Code functionality
- 30-second timeout to prevent hanging

## Installation Details

The installer performs the following actions:

1. **Prerequisite Check**: Verifies Node.js and curl are installed
2. **Directory Setup**: Creates `~/.claude/hooks/` directory structure
3. **File Download**: Fetches latest hook files from GitHub
4. **Configuration Update**: Modifies `~/.claude/settings.json` to register hooks
5. **Validation**: Runs automated tests to verify installation

### Files Installed
```
~/.claude/
├── hooks/
│   ├── guardian-hook.js       # Main hook implementation
│   └── secrets-guardian.json  # Detection patterns configuration
└── settings.json              # Updated with hook registrations
```

## Configuration

### Custom Patterns
Add or modify detection patterns in `~/.claude/hooks/secrets-guardian.json`:

```json
{
  "patterns": {
    "custom_secrets": [
      "CUSTOM_API_KEY=[A-Za-z0-9]{32}",
      "internal_token=[A-Za-z0-9-_]{40}"
    ]
  }
}
```

### Disable Specific Checks
To temporarily disable the Guardian, remove or comment out hook entries in `~/.claude/settings.json`.

## Testing

### Quick Manual Test

Try asking Claude Code to create a file with a secret to verify the Guardian is working:

```
"Create a file test.txt with the content: AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
```

The Guardian should block this operation with a security warning.

### Automated Test Suite

The test suite validates both secret detection and safe content handling:

```bash
# Run comprehensive tests
./test.sh

# Test specific hook functionality
echo '{"toolName":"Write","toolInput":{"content":"API_KEY=secret123"}}' | \
  node ~/.claude/hooks/guardian-hook.js
```

## Troubleshooting

### Hook Not Triggering
1. Verify installation: Check `~/.claude/settings.json` contains hook entries
2. Test manually: Run test commands to validate hook functionality
3. Check Node.js: Ensure Node.js is in PATH and executable

### False Positives
- Review patterns in `secrets-guardian.json`
- Submit issue with example for pattern refinement
- Temporarily disable specific patterns if needed

### Performance Issues
- Hook has 30-second timeout (Claude Code limit is 60 seconds)
- Large file operations may experience slight delays
- Consider pattern optimization for frequently triggered rules

## Security Considerations

- **Local Processing**: All scanning happens locally, no data sent externally
- **Non-Persistent**: Doesn't store or log detected secrets
- **Fail-Safe**: Errors in hook don't block Claude Code operations
- **Configurable**: Full control over detection patterns

## Requirements

- **Node.js**: Version 14 or higher
- **Claude Code**: Latest version with hook support
- **Operating System**: macOS, Linux, or WSL on Windows

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Add tests for new patterns
3. Update documentation
4. Submit a pull request

### Development

```bash
# Clone repository
git clone https://github.com/refcell/guardian
cd guardian

# Run tests locally
./test.sh

# Test specific patterns
./test-hook.sh
```

## License

MIT - See [LICENSE](LICENSE) for details

## Links

- [GitHub Repository](https://github.com/refcell/guardian)
- [Report Issues](https://github.com/refcell/guardian/issues)
- [Feature Requests](https://github.com/refcell/guardian/discussions)

## Acknowledgments

Built for the Claude Code community to enhance security during AI-assisted development.