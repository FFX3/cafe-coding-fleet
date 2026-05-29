# Previous Infrastructure Attempt Reference

> **Why abandoned**: COS (Container-Optimized OS) cannot run locally and creates GCP vendor lock-in. Talos Linux solves both issues. Additionally, Talos has no SSH/shell access, which forces all configuration to be declarative - no undocumented bash script fixes.

Reference implementation at `~/infrastructure_/terraform/` for GCP/Terraform patterns only.

## Terraform Structure
```
infrastructure_/terraform/
├── local/          # QEMU-based local dev environment
├── prod/           # Production GCP deployment
│   ├── compute.tf  # e2-medium instance with Container-Optimized OS
│   ├── storage.tf  # 50GB pd-ssd persistent disk
│   ├── networking.tf # Firewall rules (22, 80, 6610)
│   └── images.tf   # Docker image build/push via SSH
├── modules/
│   └── services/   # Shared service definitions (systemd units, env files, nginx)
└── result
```

## Key Patterns
- **Region**: `northamerica-northeast1` (Montreal)
- **Persistent storage**: Separate pd-ssd disk mounted at `/mnt/disks/persistent_data`
- **Service architecture**: PostgreSQL, Redis, Frappe, nginx as systemd-managed Docker containers
- **Config sync**: SSH provisioners to update configs without VM recreation
- **Shared modules**: Same service definitions for local and prod environments

## GCP Resources Provisioned
- **Compute**: `e2-medium` (2 vCPU, 4GB RAM) with Container-Optimized OS
- **Storage**: 50GB `pd-ssd` at `/mnt/disks/persistent_data`
- **Firewall**: Ports 22, 80, 6610

## Service Stack
- PostgreSQL 16-alpine (port 5432)
- Redis 7-alpine
- Frappe (gunicorn 8000, socketio 9000)
- nginx reverse proxy (port 80)
