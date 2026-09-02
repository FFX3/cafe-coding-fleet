# Passbolt

Team password manager at https://passbolt.justinmcintyre.com

## Database

Uses PostgreSQL (shared postgres instance, dedicated `passbolt` database).

## Users

Define users in `config/passbolt/users.enc.yaml`:

```bash
sops config/passbolt/users.enc.yaml
```

Format:

```yaml
users:
  - email: admin@example.com
    first_name: Admin
    last_name: User
    role: admin
  - email: user@example.com
    first_name: Regular
    last_name: User
    role: user
```

The deploy script creates users idempotently and outputs setup URLs. Users complete setup in their browser (Passbolt extension handles GPG key generation/import).

## Server GPG Keys

Auto-generated on first boot. No manual setup required.

## Email

Uses the central email relay (`smtp.email.svc.cluster.local`). See [email.md](email.md).
