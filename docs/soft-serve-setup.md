# soft-serve Setup

Minimal Git server from Charm. SSH-based, uses SQLite, very lightweight.

## Purpose

Backup git remote in case GitHub is down. No CI/CD, no project management - just git push/pull.

## Docker Image

```
charmcli/soft-serve
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 23231 | TCP | SSH (main interface, git operations) |
| 23232 | TCP | HTTP (web UI, git clone over HTTP) |

## Environment Variables

| Variable | Purpose | Value |
|----------|---------|-------|
| `SOFT_SERVE_DATA_PATH` | Data directory (repos, SQLite DB, keys) | `/data` (mount persistent disk here) |
| `SOFT_SERVE_CONFIG_LOCATION` | Path to config.yaml | `/config/config.yaml` (from ConfigMap) |
| `SOFT_SERVE_INITIAL_ADMIN_KEYS` | SSH public keys for initial admin | Your machine's public key |

All config.yaml settings can be overridden with `SOFT_SERVE_` prefixed env vars (uppercase).

## Usage

Once deployed:

```bash
# Add as remote
git remote add backup ssh://git.justinmcintyre.com:23231/your-repo

# Push
git push backup main

# Clone
git clone ssh://git.justinmcintyre.com:23231/your-repo
```

## Resources

- GitHub: https://github.com/charmbracelet/soft-serve
- Docs: https://charm.sh/soft-serve
