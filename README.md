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

## Quick Installation

Install with one simple command:

```bash
# Short version (once deployed to guardian.refcell.org)
curl -sSL guardian.refcell.org/install | bash
```

Or use the GitHub URL directly:

```bash
curl -sSL https://raw.githubusercontent.com/refcell/guardian/main/install.sh | bash
```

Prefer to review first? Download and inspect:

```bash
curl -sSL guardian.refcell.org/install -o install-guardian.sh
cat install-guardian.sh  # Review the script
bash install-guardian.sh
```

## Manual Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/refcell/guardian.git
cd guardian
./install.sh
```

## What Gets Installed

The installer will:
1. Download hook scripts to `~/.config/claude/hooks/`
2. Download agent configurations to `~/.config/claude/agents/`
3. Update or create `~/.config/claude/settings.json` with hook configurations
4. Run tests to verify the installation works

## Testing

After installation, run the comprehensive test suite to verify everything is working:

```bash
# Short version (once deployed)
curl -sSL guardian.refcell.org/test | bash
```

Or using GitHub directly:

```bash
curl -sSL https://raw.githubusercontent.com/refcell/guardian/main/test.sh | bash
```

The test script will:
- Verify the hook is properly installed
- Test detection of various secret types
- Confirm safe content isn't blocked
- Check hook configuration in settings.json

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

## Requirements

- Node.js (for running the hook)
- curl (for remote installation)
- Claude CLI configured on your system

## Uninstallation

To remove the hook:
1. Remove hook entries from `~/.config/claude/settings.json`
2. Delete `~/.config/claude/hooks/secure-command.js`
3. Delete `~/.config/claude/agents/secrets-guardian.json`

## License

MIT License - See [LICENSE](LICENSE) file for details.