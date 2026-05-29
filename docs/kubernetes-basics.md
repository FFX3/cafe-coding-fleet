# Kubernetes Basics

Context for this single-node Talos cluster.

## Core Concepts

**Pod** = One or more containers that run together. Smallest deployable unit in Kubernetes.

**Node** = A machine (VM or physical) that runs pods. Our setup has one node: `talos-controlplane`.

**Scheduler** = Control plane component that decides which node runs each pod.

## Taints and Tolerations

Taints and tolerations control which pods can run on which nodes.

**Taint** = Label on a node saying "reject pods unless they tolerate me"

**Toleration** = Label on a pod saying "I can handle that taint"

```
┌─────────────┐         ┌─────────────┐
│   Node A    │         │   Node B    │
│  taint: X   │         │  (no taint) │
└─────────────┘         └─────────────┘
      ↑                       ↑
      │                       │
      │ rejected              │ scheduled here
      │                       │
┌─────────────────────────────┴───┐
│  Scheduler: "where does pod go?" │
└─────────────────────────────────┘
      ↑
┌─────────────┐
│    Pod      │
│ (no toleration for X)
└─────────────┘
```

### The Control Plane Taint

By default, Kubernetes taints control plane nodes with:

```
node-role.kubernetes.io/control-plane:NoSchedule
```

This prevents regular workloads from running on control plane nodes, reserving them for cluster management (API server, etcd, scheduler).

### Why This Matters for Single-Node Clusters

In a typical production cluster:
- **Control plane nodes** run cluster management only
- **Worker nodes** run your applications

In our single-node setup, one node does both jobs. Without removing the taint, application pods have nowhere to go - the only node rejects them.

### Our Solution

The bootstrap scripts (`scripts/bootstrap-gcp.sh` and `scripts/local-cluster.sh`) automatically remove the taint after cluster creation:

```bash
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

The trailing `-` removes the taint.

### Verifying Taints

Check current taints on a node:

```bash
kubectl describe node talos-controlplane | grep -A 3 Taints
```

Expected output for our setup (no taints blocking workloads):

```
Taints:             <none>
```

## Reference

- [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Kubernetes Scheduling](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
