# cloud-k8s

A highly available Kubernetes cluster on the free tiers of three clouds plus a self-hosted VPS. Everything that can be is described as code: clouds with Terraform, nodes with Ansible, the cluster with manifests.

```
                    Oracle NLB (L4)
                          │
   ┌──────────── WireGuard mesh ───────────────────────────┐
   │  GCP Madrid:     cp1  cp2  cp3   (kubeadm, etcd ×3)   │
   │  Oracle Madrid:  w-oci1  w-oci2  (arm64)              │
   │  AWS Spain:      w-aws1  (amd64)                      │
   │  VPS Madrid:     vps1    (amd64)                      │
   │  Calico VXLAN over WireGuard                          │
   └───────────────────────────────────────────────────────┘
```

## Layout

| Directory | Contents |
|---|---|
| `terraform/bootstrap/` | foundation: Always Free quotas, state bucket (local state) |
| `terraform/modules/` | VMs and networks per provider, NetBox registration |
| `terraform/envs/lab/` | root configuration: backend, providers, module calls |
| `ansible/` | node setup: WireGuard, base, kubeadm. Inventory comes from NetBox |
| `k8s/platform/` | CNI, Gateway API, monitoring |
| `k8s/apps/` | workloads |
| `docs/adr/` | architecture decisions: why this way and not another |

## Decisions

- [0001 — kubeadm with our own roles](docs/adr/0001-kubeadm.md)
- [0002 — control plane in a single cloud](docs/adr/0002-control-plane-single-cloud.md)
- [0003 — Terraform state in OCI Object Storage](docs/adr/0003-terraform-state-oci.md)
- [0004 — NetBox as the source of truth](docs/adr/0004-netbox-source-of-truth.md)
