# Claude Secrets Guardian Hook

A security hook for Claude that prevents accidental exposure of secrets, API keys, tokens, and other sensitive information.

## Features

- **Real-time Secret Detection**: Scans content before file writes, edits, bash commands, and git commits
- **Comprehensive Pattern Matching**: Detects:
  - API keys and tokens (AWS, GitHub, Slack, JWT, etc.)
  - Private keys (RSA, EC, DSA, PGP)
  - Database connection strings
  - Passwords and credentials
  - And more...
- **Structured Response Format**: Returns JSON with detection status, found secrets, and recommendations
- **Automatic Blocking**: Prevents operations when secrets are detected

## Installation

Run the installation script:

```bash
./install.sh
```

This will:
1. Install the hook scripts to `~/.config/claude/hooks/`
2. Copy agent configurations to `~/.config/claude/agents/`
3. Update or create `~/.config/claude/settings.json` with hook configurations
4. Create a test script to verify the installation

## Testing

After installation, test the hook:

```bash
cd claude-secrets-hook
./test-hook.sh
```

## Manual Testing

Test individual components:

```bash
# Test with direct content
echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" | node hooks/secure-command.js

# Test with file scanning
node hooks/secure-command.js --file /path/to/file

# Test with command scanning
node hooks/secure-command.js --command "export API_KEY=sk-1234567890"
```

## Response Format

The hook returns a JSON response:

```json
{
  "status": "safe|warning|danger",
  "secrets_found": [
    {
      "type": "api_keys",
      "match": "api_key = 'sk-proj-abc...",
      "line": 42,
      "position": 150
    }
  ],
  "recommendations": [
    "Remove hardcoded secrets from the code",
    "Use environment variables for sensitive configuration"
  ],
  "blocked": true
}
```

## Hook Points

The secrets guardian is configured to run at these points:
- **pre-write**: Before writing files
- **pre-edit**: Before editing files
- **pre-bash**: Before executing bash commands
- **pre-commit**: Before git commits

## Customization

Edit `agents/secrets-guardian.json` to:
- Add new secret patterns
- Modify detection rules
- Customize response messages

## Uninstallation

To remove the hook:
1. Remove hook entries from `~/.config/claude/settings.json`
2. Delete `~/.config/claude/hooks/secure-command.js`
3. Delete `~/.config/claude/agents/secrets-guardian.json`