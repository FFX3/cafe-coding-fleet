# Cloudflare Setup

This guide walks through getting the Cloudflare API token and Zone ID needed for DNS management.

## Prerequisites

- A Cloudflare account with a domain (e.g., justinmcintyre.com)
- The domain's DNS managed by Cloudflare

## Step 1: Get Your Zone ID

1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click on your domain (e.g., justinmcintyre.com)
3. On the **Overview** page, look at the right sidebar
4. Find **Zone ID** and copy it

It looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`

## Step 2: Create an API Token

1. Click your profile icon (top right) → **My Profile**
2. Go to **API Tokens** tab
3. Click **Create Token**
4. Click **Use template** next to "Edit zone DNS"

### Configure the Token

**Permissions** (should be pre-filled):
- Zone - DNS - Edit

**Zone Resources**:
- Include - Specific zone - `justinmcintyre.com`

**Client IP Address Filtering** (optional):
- Add your home/office IP for extra security

**TTL** (optional):
- Set an expiration date if desired

5. Click **Continue to summary**
6. Click **Create Token**
7. **Copy the token immediately** - it's only shown once!

The token looks like: `abcdef1234567890abcdef1234567890abcdef12`

## Step 3: Add to Encrypted Secrets

```bash
# Edit the encrypted secrets file
sops terraform/secrets.enc.yaml
```

Add both values:

```yaml
cloudflare_api_token: "abcdef1234567890abcdef1234567890abcdef12"
cloudflare_zone_id: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
```

Save and close. SOPS encrypts automatically.

## Step 4: Verify

```bash
cd terraform
terraform init
terraform plan
```

You should see the Cloudflare DNS record in the plan output:

```
+ resource "cloudflare_record" "test" {
    + name    = "test"
    + type    = "A"
    + content = (known after apply)
    ...
  }
```

## What Gets Created

Terraform creates a DNS A record:
- **Name**: `test.justinmcintyre.com`
- **Type**: A
- **Content**: Your GCP instance's external IP
- **TTL**: 60 seconds (1 minute)
- **Proxied**: No (direct connection)

The record updates automatically when you redeploy (new IP).

## Token Security

The API token has minimal permissions:
- Can only edit DNS records
- Only for your specific zone
- Cannot access other Cloudflare features

If compromised, an attacker could only modify your DNS records, not access your account or other settings.

## Rotating the Token

If you need to rotate the token:

1. Create a new token (follow Step 2)
2. Update the encrypted secrets:
   ```bash
   sops terraform/secrets.enc.yaml
   ```
3. Replace `cloudflare_api_token` with the new value
4. Delete the old token in Cloudflare dashboard

## Troubleshooting

### "Invalid API Token"

- Token may have expired
- Token may have been deleted
- Verify you copied the full token (no extra spaces)

### "Zone not found"

- Zone ID may be incorrect
- Token may not have permission for this zone
- Verify zone ID from Cloudflare dashboard

### DNS record not updating

- TTL is 60 seconds - wait for propagation
- Check `terraform apply` output for errors
- Verify with: `dig test.justinmcintyre.com`
