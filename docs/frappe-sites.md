# Frappe Sites Management

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ ConfigMap: frappe-sites                                      │
│   - Defines apps to install (git repos)                      │
│   - Defines sites (hostname, database, apps)                 │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Init Container: provision-sites                              │
│   1. Initialize bench (if not exists)                        │
│   2. Install apps via bench get-app                          │
│   3. Create PostgreSQL database/user per site                │
│   4. Create Frappe site (bench new-site)                     │
│   5. Install apps on site                                    │
│   6. Run migrations                                          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Frappe Pod                                                   │
│   ├─ gunicorn    (web server, port 8000)                     │
│   ├─ socketio    (realtime, port 9000)                       │
│   ├─ worker      (background jobs)                           │
│   └─ scheduler   (scheduled tasks)                           │
└─────────────────────────────────────────────────────────────┘
```

### Key Concepts

- **Bench**: Frappe's workspace containing apps and sites
- **App**: A Frappe application (Python package with DocTypes, APIs, etc.)
- **Site**: A tenant with its own database, users, and configuration
- **PVC**: Persistent storage at `/var/mnt/data/frappe` for bench data

### Credentials Structure

Each site has its own credentials in `secret.enc.yaml`:

```yaml
stringData:
  # PostgreSQL superuser (must match apps/postgres/secret.enc.yaml)
  POSTGRES_PASSWORD: <postgres-superuser-password>

  # Per-site credentials (db_name from sites-config.yaml as prefix)
  crm_db_DB_PASSWORD: <password-for-crm_db-postgres-user>
  crm_db_ADMIN_PASSWORD: <password-for-crm-site-admin>
```

The init container looks up `{db_name}_DB_PASSWORD` and `{db_name}_ADMIN_PASSWORD` for each site.

## Adding a New App

1. Edit `apps/frappe/sites-config.yaml`:
   ```yaml
   apps:
     - name: erpnext
       url: https://github.com/frappe/erpnext
       branch: version-15
   ```

2. Redeploy:
   ```bash
   kubectl apply -f apps/frappe/sites-config.yaml
   kubectl rollout restart deployment frappe -n frappe
   ```

The init container will run `bench get-app` for any new apps.

## Adding a New Site

1. Edit `apps/frappe/sites-config.yaml`:
   ```yaml
   sites:
     - hostname: newsite.justinmcintyre.com
       db_name: newsite_db
       install_apps:
         - erpnext
   ```

2. Add credentials to `apps/frappe/secret.enc.yaml`:
   ```yaml
   stringData:
     # Per-site credentials use the db_name as prefix
     newsite_db_DB_PASSWORD: <generate-secure-password>
     newsite_db_ADMIN_PASSWORD: <generate-secure-password>
   ```
   Then re-encrypt: `sops -e -i apps/frappe/secret.enc.yaml`

3. Add hostname to `apps/frappe/ingress.yaml`:
   ```yaml
   spec:
     tls:
       - hosts:
           - newsite.justinmcintyre.com
         secretName: frappe-newsite-tls
     rules:
       - host: newsite.justinmcintyre.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: frappe
                   port:
                     number: 8000
   ```

4. Add DNS record in Cloudflare (A record pointing to cluster IP)

5. Apply and restart:
   ```bash
   kubectl apply -f apps/frappe/
   kubectl rollout restart deployment frappe -n frappe
   ```

## Removing a Site

1. Remove from `sites-config.yaml` (site directory remains)
2. Remove from `ingress.yaml`
3. Apply changes

**Note**: Database is NOT deleted automatically. To fully remove:
```bash
./scripts/db-connect.sh
DROP DATABASE site_db;
DROP USER site_db_user;
```

Then delete site directory:
```bash
kubectl exec -n frappe deploy/frappe -c gunicorn -- rm -rf /home/frappe/frappe-bench/sites/hostname
```

## Updating Apps

After pushing changes to your app repos:

```bash
# Update all apps
./scripts/bench-update.sh

# Update specific app
./scripts/bench-update.sh crm
```

This pulls latest code and runs migrations.

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n frappe
kubectl describe pod -n frappe -l app=frappe
```

### View Init Container Logs
```bash
kubectl logs -n frappe -l app=frappe -c provision-sites
```

### View Application Logs
```bash
# Web server
kubectl logs -n frappe -l app=frappe -c gunicorn -f

# Worker
kubectl logs -n frappe -l app=frappe -c worker -f

# Scheduler
kubectl logs -n frappe -l app=frappe -c scheduler -f
```

### Check Bench Status
```bash
kubectl exec -n frappe deploy/frappe -c gunicorn -- bash -c "
  cd /home/frappe/frappe-bench
  bench --site all list-apps
"
```

### Check Database Connection
```bash
./scripts/db-connect.sh
\l  -- list databases
\du -- list users
```

### Reset Everything

If provisioning is broken:

```bash
# Clear bench data
./scripts/reset-bench.sh

# Optionally drop databases
./scripts/db-connect.sh
DROP DATABASE crm_db;
DROP USER crm_db_user;

# Restart to re-provision
kubectl rollout restart deployment frappe -n frappe
```

### Common Issues

**Init container fails with "bench not found"**
- Check the frappe/bench image exists
- Check volume mounts are correct

**Database connection refused**
- Verify PostgreSQL is running: `kubectl get pods -n postgres`
- Check credentials in secret match postgres secret

**Site not accessible via browser**
- Check ingress: `kubectl get ingress -n frappe`
- Check DNS resolves to cluster IP
- Check TLS certificate: `kubectl get certificate -n frappe`

**Apps not installing**
- Check git URL is accessible
- Check branch exists
- View init container logs for specific error

**Missing credentials for site**
- Ensure `{db_name}_DB_PASSWORD` and `{db_name}_ADMIN_PASSWORD` exist in secret
- Check db_name in sites-config.yaml matches secret keys exactly

## How Provisioning Works

On every deployment, the init container:

1. **Checks for existing bench**
   - If `/home/frappe/frappe-bench/apps/frappe` doesn't exist, runs `bench init`
   - Otherwise skips initialization

2. **Configures Redis connections**
   - Writes `common_site_config.json` with Redis URLs

3. **Installs apps**
   - For each app in config, checks if `apps/{name}` exists
   - If not, runs `bench get-app --branch {branch} {url}`

4. **Provisions sites**
   - For each site in config:
     - Creates PostgreSQL database/user if not exists
     - Creates site directory if not exists (`bench new-site`)
     - Installs apps on site (`bench install-app`)
     - Runs migrations (`bench migrate`)

This is idempotent - running multiple times produces the same result.

## Files Reference

| File | Purpose |
|------|---------|
| `namespace.yaml` | Frappe namespace |
| `pv.yaml` | PersistentVolume for bench data |
| `pvc.yaml` | PersistentVolumeClaim |
| `sites-config.yaml` | Declarative site/app configuration |
| `provision-script.yaml` | Init container provisioning script |
| `secret.enc.yaml` | Per-site credentials (SOPS encrypted) |
| `redis.yaml` | Redis for cache and queue |
| `deployment.yaml` | Frappe deployment with all containers |
| `service.yaml` | ClusterIP service |
| `ingress.yaml` | Ingress rules per site |
