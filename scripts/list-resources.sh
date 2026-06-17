#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/internal/require-env.sh"

PROJECT_ID="cafe-coding-fleet"

echo "GCP Resources for project: $PROJECT_ID"
echo "========================================"
echo ""

echo "Compute Instances"
echo "-----------------"
gcloud compute instances list --project="$PROJECT_ID" --format="table(name, zone, machineType.basename(), status, networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"
echo ""

echo "Disks"
echo "-----"
gcloud compute disks list --project="$PROJECT_ID" --format="table(name, zone, sizeGb, type.basename(), status)"
echo ""

echo "Images"
echo "------"
gcloud compute images list --project="$PROJECT_ID" --no-standard-images --format="table(name, diskSizeGb, status)"
echo ""

echo "Firewall Rules"
echo "--------------"
gcloud compute firewall-rules list --project="$PROJECT_ID" --format="table(name, network.basename(), direction, allowed[].map().firewall_rule().list():label=ALLOW)"
echo ""

echo "Storage Buckets"
echo "---------------"
gsutil ls -p "$PROJECT_ID"
echo ""

echo "Bucket Contents (sizes)"
echo "-----------------------"
for bucket in $(gsutil ls -p "$PROJECT_ID"); do
    gsutil du -sh "$bucket" 2>/dev/null || echo "$bucket (empty or no access)"
done
echo ""

echo "External IPs"
echo "------------"
gcloud compute addresses list --project="$PROJECT_ID" --format="table(name, region, address, status)" 2>/dev/null || echo "(no reserved IPs - using ephemeral)"
echo ""

echo "========================================"
echo "Done. See docs/gcp-costs.md for pricing."
