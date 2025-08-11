# Claude Secrets Guardian 🔒

Protect your Claude sessions from accidentally exposing secrets, API keys, and sensitive information.

## Installation

```bash
curl -sSL guardian.refcell.org/install | bash
```

## Testing

Verify the installation:

```bash
curl -sSL guardian.refcell.org/test | bash
```

## What It Does

The guardian monitors Claude operations and blocks attempts to:
- Write files containing secrets
- Execute commands with exposed credentials  
- Commit sensitive data to git

Detects: AWS keys, API tokens, passwords, private keys, database URLs, JWTs, and more.

## Uninstall

```bash
curl -sSL guardian.refcell.org/uninstall | bash
```

## How It Works

Installs hooks into `~/.config/claude/settings.json` that scan content before:
- File writes/edits (`pre-write`, `pre-edit`)
- Command execution (`pre-bash`)
- Git commits (`pre-commit`)

When secrets are detected, operations are blocked with a JSON response explaining what was found.

## Customization

Edit patterns in `~/.config/claude/agents/secrets-guardian.json` to add/modify detection rules.

## Requirements

- Node.js
- Claude CLI

## License

MIT - See [LICENSE](LICENSE)

## Links

- [GitHub Repository](https://github.com/refcell/guardian)
- [Report Issues](https://github.com/refcell/guardian/issues)