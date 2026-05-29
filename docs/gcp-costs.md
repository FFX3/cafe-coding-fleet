# GCP Costs

Monthly cost breakdown for this infrastructure.

## Current Resources

List all resources in the project:

```bash
# Compute instances
gcloud compute instances list --project=cafe-coding-fleet

# Disks (boot + data)
gcloud compute disks list --project=cafe-coding-fleet

# Custom images
gcloud compute images list --project=cafe-coding-fleet --no-standard-images

# Firewall rules
gcloud compute firewall-rules list --project=cafe-coding-fleet

# Storage buckets
gsutil ls -p cafe-coding-fleet

# Everything at once (requires Cloud Asset API enabled)
gcloud asset search-all-resources --project=cafe-coding-fleet
```

## Cost Breakdown

**Estimated Total: ~$50/month USD**

Use the [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for accurate estimates.

Region: `northamerica-northeast1` (Montreal)

| Resource | Spec |
|----------|------|
| VM | e2-medium (2 vCPU, 4GB), 730 hrs/month |
| Boot disk | 10GB pd-standard |
| Data disk | 20GB pd-ssd |
| GCS bucket | ~1GB (Talos image) |
| Firewall rules | 3 rules (free) |
| External IP | Ephemeral while attached (free) |

## Pricing Sources

- [Compute Engine Pricing](https://cloud.google.com/compute/vm-instance-pricing)
- [Disk Pricing](https://cloud.google.com/compute/disks-image-pricing)
- [Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [Network Pricing](https://cloud.google.com/vpc/network-pricing)

## Verify Actual Costs

Check real billing in GCP Console:

1. Go to [Billing Reports](https://console.cloud.google.com/billing)
2. Select project `cafe-coding-fleet`
3. View by SKU to see line-item costs

Or use CLI:

```bash
# Requires Billing API access
gcloud billing accounts list
```

## Cost Optimization Options

Not needed now, but for reference:

| Option | Savings | Trade-off |
|--------|---------|-----------|
| Spot VM | ~60-70% | Can be preempted with 30s notice |
| Committed use (1yr) | ~37% | Locked in for 1 year |
| Committed use (3yr) | ~55% | Locked in for 3 years |
| e2-small instead | ~50% | Only 2GB RAM |
| pd-standard instead of pd-ssd | ~50% on disks | Slower I/O |

## Monthly Budget Alert

Set up a budget alert to catch unexpected costs:

```bash
# Via Console: https://console.cloud.google.com/billing/budgets
# Or use gcloud (requires billing account ID)
```
