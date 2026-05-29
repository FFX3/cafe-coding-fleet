# SOPS Secrets Management

This project uses [SOPS](https://github.com/getsops/sops) (Secrets OPerationS) with [age](https://github.com/FiloSottile/age) encryption to manage sensitive data like API tokens.

## Why SOPS + Age?

- **Encrypted at rest**: Secrets are encrypted in the repo, safe to commit
- **Version controlled**: Track secret changes alongside code
- **Simple key management**: Age uses a single key file, no GPG complexity
- **Terraform integration**: SOPS provider decrypts secrets during `terraform apply`

## Key Concepts

- **Age key pair**: A public key (for encryption) and private key (for decryption)
- **Public key**: Shared in `.sops.yaml`, used by SOPS to encrypt
- **Private key**: Kept in `~/.config/sops/age/keys.txt`, never committed
- **Encrypted file**: `terraform/secrets.enc.yaml` - safe to commit

## First-Time Setup

### 1. Generate an Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

This outputs something like:
```
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

**Save this public key** - you'll need it for the next step.

### 2. Configure SOPS

Edit `.sops.yaml` at the repo root and replace the placeholder with your public key:

```yaml
creation_rules:
  - path_regex: \.enc\.yaml$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 3. Create Encrypted Secrets

```bash
sops terraform/secrets.enc.yaml
```

This opens your `$EDITOR`. Add your secrets:

```yaml
cloudflare_api_token: "your-actual-token-here"
cloudflare_zone_id: "your-zone-id-here"
```

Save and close. SOPS encrypts the file automatically.

### 4. Verify Encryption

```bash
cat terraform/secrets.enc.yaml
```

You should see encrypted content like:
```yaml
cloudflare_api_token: ENC[AES256_GCM,data:...,type:str]
cloudflare_zone_id: ENC[AES256_GCM,data:...,type:str]
sops:
    age:
        - recipient: age1ql3z7hjy...
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

## Adding/Editing Secrets

To modify existing secrets:

```bash
sops terraform/secrets.enc.yaml
```

SOPS decrypts the file, opens your editor, then re-encrypts on save.

To add a new secret, just add a new key in the editor:

```yaml
cloudflare_api_token: "existing-token"
cloudflare_zone_id: "existing-zone"
new_secret: "new-value"
```

## Setting Up on a New Machine

1. Copy your age private key from your existing machine:
   ```bash
   # On new machine
   mkdir -p ~/.config/sops/age

   # Copy keys.txt from existing machine to ~/.config/sops/age/keys.txt
   ```

2. Verify you can decrypt:
   ```bash
   sops -d terraform/secrets.enc.yaml
   ```

**Important**: Never commit or share `keys.txt`. If lost, you'll need to re-encrypt all secrets with a new key.

## How Terraform Uses Secrets

The SOPS provider in `terraform/main.tf` reads encrypted secrets:

```hcl
data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
}
```

When you run `terraform apply`:
1. SOPS provider reads `secrets.enc.yaml`
2. Decrypts using your age key at `~/.config/sops/age/keys.txt`
3. Makes values available as `data.sops_file.secrets.data["key_name"]`

## Environment Variable Alternative

If your key is in a non-standard location:

```bash
export SOPS_AGE_KEY_FILE=/path/to/your/keys.txt
terraform apply
```

## Troubleshooting

### "could not decrypt data key"

Your age private key isn't available or doesn't match.

**Check key exists:**
```bash
ls -la ~/.config/sops/age/keys.txt
```

**Check key matches:**
```bash
# Get public key from your private key
age-keygen -y ~/.config/sops/age/keys.txt

# Compare with the recipient in the encrypted file
grep -A5 "age:" terraform/secrets.enc.yaml
```

### "no matching keys found"

The encrypted file was created with a different age key.

**Solution**: Get the correct private key from whoever encrypted the file, or re-encrypt with your key:

```bash
# Someone with the original key decrypts
sops -d terraform/secrets.enc.yaml > /tmp/secrets.yaml

# You encrypt with your key (after updating .sops.yaml with your public key)
sops -e /tmp/secrets.yaml > terraform/secrets.enc.yaml
rm /tmp/secrets.yaml
```

### "Error getting data key"

SOPS can't find any key to decrypt with.

**Check SOPS_AGE_KEY_FILE:**
```bash
echo $SOPS_AGE_KEY_FILE
```

**Check default location:**
```bash
cat ~/.config/sops/age/keys.txt
```

### Terraform fails with "secrets" errors

Run `terraform init` to install the SOPS provider:

```bash
cd terraform
terraform init
```

## Security Best Practices

1. **Never commit `keys.txt`** - It's in `.gitignore` but double-check
2. **Backup your key securely** - Store in a password manager
3. **Rotate keys periodically** - Generate new key, re-encrypt secrets
4. **One key per person** - For teams, each member has their own key listed in `.sops.yaml`

## File Reference

| File | Purpose | Commit? |
|------|---------|---------|
| `.sops.yaml` | SOPS config with public keys | Yes |
| `terraform/secrets.enc.yaml` | Encrypted secrets | Yes |
| `~/.config/sops/age/keys.txt` | Private key | **NO** |
