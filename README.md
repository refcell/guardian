# Claude Secrets Guardian 🛡️

[![Status](https://img.shields.io/badge/status-active-success.svg)](https://github.com/refcell/guardian)
[![Security](https://img.shields.io/badge/security-enabled-blue.svg)](https://github.com/refcell/guardian)

Prevent accidental exposure of secrets, API keys, and passwords in Claude Code sessions.

## Quick Install

```bash
curl -sSL guardian.refcell.org/install | bash
```

## What It Does

Guardian blocks Claude Code from:
- Writing secrets to files
- Running commands with exposed credentials  
- Displaying sensitive data in responses
- Committing secrets to git

## Protected Secrets

- **API Keys**: OpenAI, Stripe, AWS, GitHub tokens
- **Credentials**: Passwords, database URLs, JWT tokens
- **Private Keys**: SSH, RSA, PGP keys
- **Webhooks**: Slack, Discord URLs

## Test It Works

```bash
# Quick test
curl -sSL guardian.refcell.org/test | bash

# Or ask Claude to write a secret (will be blocked):
# "Create test.txt with AWS_ACCESS_KEY_ID=AKIA[EXAMPLE]"
```

## Uninstall

```bash
curl -sSL guardian.refcell.org/uninstall | bash
```

## How It Works

Guardian uses Claude Code's hook system to scan operations before execution:

1. **PreToolUse**: Blocks Write/Edit/Bash operations with secrets
2. **Stop**: Prevents secrets in Claude's responses
3. **SessionStart**: Shows security status on startup

Files installed in `~/.claude/hooks/`:
- `guardian-hook.js` - Main scanner
- `secrets-guardian.json` - Detection patterns
- `session-start-hook.js` - Startup notifications

## Troubleshooting

**Not working?**
- Check installation: `grep guardian ~/.claude/settings.json`
- Test manually: `./test.sh`
- Enable debug: `export GUARDIAN_DEBUG=true`

**False positives?**
- Edit patterns: `~/.claude/hooks/secrets-guardian.json`
- Report issues: [GitHub](https://github.com/refcell/guardian/issues)

## Requirements

- Node.js 14+
- Claude Code (latest)
- macOS/Linux/WSL

## Contributing

```bash
git clone https://github.com/refcell/guardian
cd guardian
./test.sh
```

## License

MIT - See [LICENSE](LICENSE)

---

Built for safer AI-assisted development with Claude Code.