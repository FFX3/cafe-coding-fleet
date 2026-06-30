# Wiping PVC Data

Persistent Volume Claims (PVCs) retain data across pod restarts. Sometimes you need to wipe this data completely (e.g., corrupted state, fresh start, password issues).

## Important

Deleting a PVC/PV does **not** delete the underlying data. The data lives on the host disk and must be wiped separately.

## Generic Wipe Procedure

For any application with a PVC:

### 1. Scale Down the Deployment

```bash
kubectl scale deployment/<app> -n <namespace> --replicas=0
# or for StatefulSets:
kubectl scale statefulset/<app> -n <namespace> --replicas=0
```

### 2. Run a Wipe Pod

```bash
kubectl run wipe-<app> -n <namespace> --rm -it --restart=Never \
  --image=busybox:1.36 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "wipe",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; ls -la /data; echo done"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {"claimName": "<pvc-name>"}
      }]
    }
  }'
```

### 3. Scale Back Up

```bash
kubectl scale deployment/<app> -n <namespace> --replicas=1
```

## Application-Specific Commands

### Conduit (Matrix)

```bash
kubectl scale deployment/conduit -n conduit --replicas=0

kubectl run wipe-conduit -n conduit --rm -it --restart=Never \
  --image=busybox:1.36 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "wipe",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; ls -la /data; echo done"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {"claimName": "conduit-pvc"}
      }]
    }
  }'

kubectl scale deployment/conduit -n conduit --replicas=1
```

**After wiping Conduit**: Redeploy to recreate users:
```bash
nix run .#deploy-conduit
```

### Hermes

```bash
kubectl scale deployment/hermes -n hermes --replicas=0

kubectl run wipe-hermes -n hermes --rm -it --restart=Never \
  --image=busybox:1.36 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "wipe",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; ls -la /data; echo done"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {"claimName": "hermes-pvc"}
      }]
    }
  }'

kubectl scale deployment/hermes -n hermes --replicas=1
```

### PostgreSQL

**Warning**: This deletes all databases (Twenty, Hermes, etc.)

```bash
kubectl scale statefulset/postgres -n postgres --replicas=0

kubectl run wipe-postgres -n postgres --rm -it --restart=Never \
  --image=busybox:1.36 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "wipe",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; ls -la /data; echo done"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {"claimName": "postgres-pvc"}
      }]
    }
  }'

kubectl scale statefulset/postgres -n postgres --replicas=1
```

**After wiping PostgreSQL**: Redeploy apps that depend on it:
```bash
nix run .#deploy-twenty
nix run .#deploy-hermes
```

### Twenty CRM

Twenty uses a shared PVC between server and worker.

```bash
kubectl scale deployment/twenty-server -n twenty --replicas=0
kubectl scale deployment/twenty-worker -n twenty --replicas=0

kubectl run wipe-twenty -n twenty --rm -it --restart=Never \
  --image=busybox:1.36 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "wipe",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "rm -rf /data/* /data/.[!.]* 2>/dev/null; ls -la /data; echo done"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {"claimName": "twenty-server-pvc"}
      }]
    }
  }'

kubectl scale deployment/twenty-server -n twenty --replicas=1
kubectl scale deployment/twenty-worker -n twenty --replicas=1
```

## Why Not Just Delete PVC/PV?

The PVs use `hostPath` storage with `persistentVolumeReclaimPolicy: Retain`. This means:

1. Deleting the PVC unbinds it from the PV
2. Deleting the PV removes the Kubernetes object
3. **The data on disk remains** at `/var/mnt/data/<app>`

Using a wipe pod is the cleanest way to clear data without needing Talos shell access.

## PVC Locations

| App | PVC Name | Host Path |
|-----|----------|-----------|
| Conduit | conduit-pvc | /var/mnt/data/conduit |
| Hermes | hermes-pvc | /var/mnt/data/hermes |
| PostgreSQL | postgres-pvc | /var/mnt/data/postgres |
| Twenty | twenty-server-pvc | /var/mnt/data/twenty |
| Redis | twenty-redis-pvc | /var/mnt/data/redis |
