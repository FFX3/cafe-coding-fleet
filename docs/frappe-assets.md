# Frappe Pre-built Assets

Frappe's frontend build (Vite/esbuild) requires more memory than the e2-medium VM provides.
Instead of building on the VM, we pre-build assets locally and download them during provisioning.

## How It Works

1. **Local build**: Run `./scripts/build-frappe-assets.sh` in the nix shell
2. **Upload to GCS**: Script uploads tarball + manifest to private GCS bucket
3. **Provisioning**: Init container downloads and extracts pre-built assets
4. **Versioning**: Manifest comparison determines if update is needed

## First-Time Setup

### 1. Apply Terraform (creates service account)

```bash
cd terraform
terraform apply
cd ..
```

This creates:
- Service account: `frappe-assets-reader@cafe-coding-fleet.iam.gserviceaccount.com`
- IAM binding: `roles/storage.objectViewer` on the Talos images bucket

### 2. Generate and Add Service Account Key

```bash
./scripts/setup-frappe-gcs-key.sh
```

This script:
- Generates a service account key via `gcloud`
- Adds it to `apps/frappe/secret.enc.yaml` (SOPS encrypted)
- Cleans up the temporary key file

**Manual alternative** (if script fails):

```bash
# Generate key
gcloud iam service-accounts keys create /tmp/frappe-gcs-key.json \
  --iam-account=frappe-assets-reader@cafe-coding-fleet.iam.gserviceaccount.com

# Edit secret
sops apps/frappe/secret.enc.yaml

# Add under stringData:
gcs-service-account.json: |
  {paste entire JSON key contents}

# Clean up
rm /tmp/frappe-gcs-key.json
```

### 3. Build and Upload Assets

```bash
nix develop
./scripts/build-frappe-assets.sh
```

### 4. Deploy

```bash
kubectl apply -f apps/frappe/
kubectl delete pod -n frappe -l app=frappe
```

## Building Assets

Run whenever apps or Frappe version changes:

```bash
nix develop
./scripts/build-frappe-assets.sh
```

The script:
1. Creates Python venv and installs frappe-bench
2. Initializes bench with Frappe v16
3. Installs apps (CRM from your fork)
4. Runs `bench build` to compile frontend
5. Generates `manifest.json` with commit SHAs
6. Uploads to GCS

## When to Rebuild

- Adding/removing apps in `sites-config.yaml`
- Changing app branch/version
- Upgrading Frappe version
- Pulling new commits from app repos

After rebuilding, trigger re-provisioning:

```bash
kubectl delete pod -n frappe -l app=frappe
```

## Manifest Versioning

The manifest contains:

```json
{
  "frappe_version": "version-16",
  "build_date": "2026-06-04T12:34:56Z",
  "apps": {
    "frappe": "abc123...",
    "crm": "def456..."
  }
}
```

Init container compares local vs remote manifest:
- Different: downloads new tarball
- Same: skips download

The `build_date` means every rebuild triggers an update.

## Site Data Preservation

The `sites/` directory contains all user data:
- `site_config.json` - Site configuration
- `private/` - Private files
- `public/files/` - Uploaded files

This is backed up before tarball extraction and restored after.

## Troubleshooting

### Build fails with missing dependency

Check flake.nix has all required packages:
- `python314` (Frappe v16 requires Python 3.14)
- `pkg-config`
- `libmysqlclient` (needed even though we use PostgreSQL)
- `nodejs_22`, `yarn`

### Download fails with "Access Denied"

Service account key not set up:
1. Check secret has `gcs-service-account.json` key
2. Check Terraform applied (service account exists)
3. Verify key is valid: `gcloud auth activate-service-account --key-file=/tmp/key.json`

### Init container OOM

Should not happen with pre-built assets. Check:
- Tarball exists in GCS
- manifest.json accessible
- Init container not running `bench build`

### "No bench found, needs fresh install" but download fails

GCS bucket or file doesn't exist. Run build script first:
```bash
./scripts/build-frappe-assets.sh
```

## Architecture

```
Local Machine                          GCS Bucket                         Kubernetes
┌─────────────────┐                   ┌─────────────┐                   ┌─────────────────┐
│ nix develop     │                   │ frappe/     │                   │ init container  │
│                 │   gsutil cp       │             │   gcs_download()  │                 │
│ build-frappe-   │ ─────────────────>│ bench.tar.gz│<──────────────────│ provision.sh    │
│ assets.sh       │                   │ manifest.json                   │                 │
└─────────────────┘                   └─────────────┘                   └─────────────────┘
```

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/build-frappe-assets.sh` | Local build and upload script |
| `scripts/setup-frappe-gcs-key.sh` | Service account key setup script |
| `terraform/frappe.tf` | Service account for GCS access |
| `apps/frappe/provision-script.yaml` | Provisioning with authenticated download |
| `apps/frappe/gcs-key.enc.json` | SOPS-encrypted GCS service account key |
| `apps/frappe/secret.enc.yaml` | Site credentials (DB passwords, admin passwords) |
