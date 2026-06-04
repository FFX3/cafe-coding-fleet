#!/usr/bin/env bash
set -euo pipefail

# Build Frappe assets locally and upload to GCS
# This avoids OOM issues on the e2-medium VM during bench build

PROJECT_ID="cafe-coding-fleet"
BUCKET_NAME="${PROJECT_ID}-talos-images"
FRAPPE_VERSION="version-16"
BUILD_DIR="/tmp/frappe-build"

# Apps to install (from sites-config.yaml)
APPS=(
    "crm|https://github.com/FFX3/crm|main"
)

echo "══════════════════════════════════════════════════════════════════"
echo "  Building Frappe Assets"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "  Frappe version: $FRAPPE_VERSION"
echo "  Build directory: $BUILD_DIR"
echo "  Target bucket: gs://${BUCKET_NAME}/frappe/"
echo ""

# Check for required tools
for cmd in python3 pip node yarn git gsutil; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is required but not found"
        echo "Run this script inside 'nix develop' shell"
        exit 1
    fi
done

echo "[1/6] Creating build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[2/6] Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet frappe-bench

echo "[3/6] Initializing bench..."
bench init frappe-bench \
    --frappe-branch "$FRAPPE_VERSION" \
    --skip-redis-config-generation \
    --no-backups

cd frappe-bench

echo "[4/6] Installing apps..."
for app_spec in "${APPS[@]}"; do
    IFS='|' read -r name url branch <<< "$app_spec"
    echo "  Installing $name from $url (branch: $branch)"
    bench get-app --branch "$branch" "$url"
done

echo "[5/6] Building all assets..."
bench build

echo "[6/6] Generating manifest and uploading..."

# Generate manifest with commit SHAs
manifest_apps=""
for app_spec in "${APPS[@]}"; do
    IFS='|' read -r name url branch <<< "$app_spec"
    sha=$(cd "apps/$name" && git rev-parse HEAD)
    manifest_apps="${manifest_apps}    \"$name\": \"$sha\",
"
done
# Remove trailing comma and newline
manifest_apps=$(echo "$manifest_apps" | sed '$ s/,$//')

frappe_sha=$(cd apps/frappe && git rev-parse HEAD)

cat > manifest.json << MANIFEST
{
  "frappe_version": "$FRAPPE_VERSION",
  "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "apps": {
    "frappe": "$frappe_sha",
$manifest_apps
  }
}
MANIFEST

echo ""
echo "Manifest:"
cat manifest.json
echo ""

# Create tarball (exclude unnecessary files, but KEEP .git for updates)
echo "Creating tarball..."
tar -czf /tmp/frappe-bench.tar.gz \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='node_modules' \
    --exclude='sites/*/private/*' \
    --exclude='sites/*/public/files/*' \
    -C "$BUILD_DIR" frappe-bench

# Also copy manifest separately for quick comparison
cp manifest.json /tmp/manifest.json

# Show tarball size
tarball_size=$(du -h /tmp/frappe-bench.tar.gz | cut -f1)
echo "Tarball size: $tarball_size"

# Upload to GCS
echo "Uploading to GCS..."
gsutil cp /tmp/frappe-bench.tar.gz "gs://${BUCKET_NAME}/frappe/frappe-bench-$(date +%Y%m%d).tar.gz"
gsutil cp /tmp/frappe-bench.tar.gz "gs://${BUCKET_NAME}/frappe/frappe-bench-latest.tar.gz"
gsutil cp /tmp/manifest.json "gs://${BUCKET_NAME}/frappe/manifest.json"

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Build Complete!"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "  Uploaded to:"
echo "    gs://${BUCKET_NAME}/frappe/frappe-bench-latest.tar.gz"
echo "    gs://${BUCKET_NAME}/frappe/manifest.json"
echo ""
echo "  To deploy: delete the frappe pod to trigger re-provisioning"
echo "    kubectl delete pod -n frappe -l app=frappe"
echo ""
