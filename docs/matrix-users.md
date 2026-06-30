# Matrix User Management

Conduit Matrix users are managed declaratively via a SOPS-encrypted config file. Users are created automatically during deployment.

## How It Works

1. Users are defined in `apps/conduit/users.enc.yaml`
2. `deploy-conduit.sh` creates users via the Matrix registration API
3. First user in the list becomes admin
4. Existing users are skipped (idempotent)

## User Config File

Create or edit the users file:

```bash
sops apps/conduit/users.enc.yaml
```

Format:

```yaml
users:
  - username: justin
    password: "secure-password-here"
  - username: hermes
    password: "another-secure-password"
```

**Important**: The first user becomes the Conduit admin automatically.

## Adding a New User

1. Edit the users file:
   ```bash
   sops apps/conduit/users.enc.yaml
   ```

2. Add the new user to the list:
   ```yaml
   users:
     - username: justin
       password: "existing-password"
     - username: hermes
       password: "existing-password"
     - username: newuser
       password: "new-user-password"
   ```

3. Redeploy Conduit:
   ```bash
   nix run .#deploy-conduit
   ```

The script will output:
```
Creating Matrix users...
  User exists: @justin:matrix.justinmcintyre.com
  User exists: @hermes:matrix.justinmcintyre.com
  Created user: @newuser:matrix.justinmcintyre.com
```

## User IDs

Matrix user IDs follow the format: `@username:matrix.justinmcintyre.com`

## Registration Token

The deploy script uses the `CONDUIT_REGISTRATION_TOKEN` from `apps/conduit/secret.enc.yaml` to authenticate user creation. This is handled automatically.

## Changing Passwords

Conduit doesn't have a built-in password reset mechanism. To change a password:

1. Remove the user from Element/Matrix client (deactivate)
2. Update the password in `users.enc.yaml`
3. Wipe Conduit data (see `docs/wipe-pvc.md`)
4. Redeploy to recreate users with new passwords

## File Reference

| File | Purpose |
|------|---------|
| `apps/conduit/users.enc.yaml` | SOPS-encrypted user list |
| `apps/conduit/secret.enc.yaml` | Registration token and JWT secret |
| `scripts/deploy-conduit.sh` | Creates users during deployment |
