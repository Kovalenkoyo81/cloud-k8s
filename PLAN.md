# Plan: HA Kubernetes cluster on cloud free tiers

Region everywhere is Madrid (close to vps1). Clouds — Terraform, nodes — Ansible, cluster — manifests.
Every step is closed by a commit through a PR with green CI.

## Architecture

```
                    Oracle NLB (free, L4)
                   443/tcp Xray · UDP second proxy
                          │
   ┌──────────── WireGuard mesh (wg0 on every node) ────────────┐
   │                                                            │
   │  GCP europe-southwest1:  cp1  cp2  cp3  (etcd ×3, kubeadm) │
   │                                                            │
   │  Oracle eu-madrid-1:  w-oci1  w-oci2  (arm64)  ← proxies,  │
   │                                                  Vault     │
   │  vps1:                worker (amd64) + relay outside k8s   │
   │  AWS eu-south-2:      w-aws1 (amd64)                       │
   │                                                            │
   │  Calico VXLAN over wg0                                     │
   └────────────────────────────────────────────────────────────┘
   GCP e2-micro (US, always free): Uptime Kuma — external watchdog
   Laptop: NetBox, Terraform, Ansible, Ansible Vault (bootstrap secrets)
```

| Node | Where | Resources | Lifetime |
|---|---|---|---|
| cp1–cp3 | GCP, e2-small (2 vCPU / 2 GB) | $300 credits | ~90 days from sign-up |
| w-oci1, w-oci2 | Oracle A1 (arm64), 1 OCPU / 6 GB each | Always Free (limit 2 OCPU / 12 GB) | no expiry |
| w-aws1 | AWS t3/t4g.small | Free plan credits | up to 6 months |
| vps1 | own VPS, 2 vCPU / 4 GB | — | no expiry |
| watchdog | GCP e2-micro (US) | Always Free | no expiry |

## Decisions

- ✅ **kubeadm with our own roles** — [ADR-0001](docs/adr/0001-kubeadm.md)
- ✅ **Masters in one cloud (GCP), workers anywhere** — [ADR-0002](docs/adr/0002-control-plane-single-cloud.md)
- ✅ **Terraform state: S3 backend on OCI Object Storage, `use_lockfile`** — [ADR-0003](docs/adr/0003-terraform-state-oci.md). If locking does not work → GitLab-managed state
- ✅ **NetBox on the laptop** — [ADR-0004](docs/adr/0004-netbox-source-of-truth.md)
- ✅ **Monorepo `cloud-k8s`**: `terraform/`, `ansible/`, `k8s/`, `docs/adr/`
- ✅ **Secrets in two layers**: bootstrap (WG keys, sudo, join) — Ansible Vault on the laptop; runtime (pod secrets) — HashiCorp Vault in the cluster via External Secrets Operator

## Open decisions
- Second proxy: AmneziaWG (proposal: an "L7 proxy + L3 VPN" pair) or Hysteria2 — decide before step 7.4

---

## Stages

### 0. Repository and accounts
- [x] **0.1** `git init`, first commit, make sure `GOAL.md`/`STATUS.md`/`CLAUDE.md` are not in git
- [x] **0.2** GitHub repository (public), push, green CI
- [x] **0.3** Ruleset on `main`: PRs only, required CI checks
- [x] **0.4** Oracle: sign-up, **home region Madrid** (cannot be changed!)
- [x] **0.5** Oracle: check `VM.Standard.A1.Flex` availability and Always Free quotas (A1, NLB, Object Storage, KMS)
- [x] **0.6** Oracle: Budget with an email alert on any spend
- [x] **0.7** AWS: sign-up, **Free plan**, MFA
- [x] **0.8** AWS: Budget (zero spend, credits excluded with a Charge type filter). Terraform access → moved to 1.8
- [x] **0.9** GCP — **do not sign up before step 4.1** (the 90 days of credits start at sign-up)

### 1. Terraform — foundation
- [x] **1.1** OCI: compartment `cloud-k8s`, group and user `terraform` (API key + Customer secret key only), policy, `~/.oci/config` (profile `cloud-k8s`), `~/.aws/credentials` (profile `oci-cloud-k8s`)
- [x] **1.2** `terraform/bootstrap/` (local state, not in git): `oci` provider, access check (Object Storage namespace)
- [x] **1.3** bootstrap: Always Free quotas (`oci_limits_quota`): A1 ≤ 2 OCPU / 12 GB, all other VM shapes = 0
- [ ] **1.4** bootstrap: state bucket in OCI Object Storage (versioning)
- [ ] **1.5** `terraform/envs/lab/`: S3 backend → OCI, `use_lockfile = true`
- [ ] **1.6** Locking test: two parallel `terraform plan` runs — the second fails on the lock
- [ ] **1.7** Module `oci-worker`: VCN, subnet, security list (51820/udp + proxy ports), 2 × A1
- [ ] **1.8** AWS: enable the opt-in region eu-south-2; Terraform access with temporary credentials (role/session, no long-lived keys); module `aws-worker`: VPC, security group, 1 VM
- [ ] **1.9** Outputs: names, public and private IPs

### 2. NetBox — source of truth
- [ ] **2.1** NetBox in Docker on the laptop, scheduled `pg_dump` backup
- [ ] **2.2** Model: sites (gcp/oci/aws/vps), roles (`control-plane`, `worker`), tags
- [ ] **2.3** Module `netbox-host`: Terraform registers VMs in NetBox
- [ ] **2.4** Ansible `nb_inventory`: groups by role and site, no static inventory
- [ ] **2.5** vps1 — into NetBox by hand or via Terraform (it is not created by Terraform)

### 3. Ansible — node preparation
- [ ] **3.1** Role `wireguard`: mesh between all nodes, keys in Ansible Vault
- [ ] **3.2** Role `base`: users and SSH hardening (based on `admin_user`)
- [ ] **3.3** Role `base`: firewall (based on `firewall`) — k8s ports, wg0 and Calico interfaces trusted
- [ ] **3.4** Role `base`: swap off, `overlay`/`br_netfilter` modules, sysctl, containerd (`SystemdCgroup = true`), chrony
- [ ] **3.5** vps1: remove k3s and LocalStack (from homelab-infra), **keep the relay on 8443**

### 4. Kubernetes — control plane and nodes
- [ ] **4.1** GCP: sign-up, $1 budget, project, service account for Terraform
- [ ] **4.2** Module `gcp-control-plane`: 3 × e2-small in three Madrid zones
- [ ] **4.3** Role `kubernetes`: kubeadm/kubelet/kubectl with pinned versions
- [ ] **4.4** API endpoint: local haproxy on every node → 3 masters
- [ ] **4.5** `kubeadm init` on cp1 (`--control-plane-endpoint`, `EncryptionConfiguration` for Secrets in etcd)
- [ ] **4.6** Join cp2, cp3 as control plane; check etcd quorum
- [ ] **4.7** Join workers: Oracle (arm64), AWS and vps1 (amd64)
- [ ] **4.8** kubeconfig on the laptop

### 5. Cluster networking
- [ ] **5.1** Calico VXLAN over wg0, MTU math (1500 → wg 1420 → vxlan 1370)
- [ ] **5.2** Check: pod ↔ pod across clouds, a large packet gets through
- [ ] **5.3** NetworkPolicy: deny traffic between namespaces and verify
- [ ] **5.4** StorageClass (local-path) for PVCs

### 6. Secrets — HashiCorp Vault
- [ ] **6.1** OCI KMS: key for auto-unseal
- [ ] **6.2** Vault in the cluster: Helm, 3 replicas, Raft, anti-affinity, auto-unseal via OCI KMS
- [ ] **6.3** Terraform `vault` provider: policies, Kubernetes auth method, KV engine
- [ ] **6.4** External Secrets Operator: secret from Vault → `Secret` in a namespace
- [ ] **6.5** Raft snapshot to OCI Object Storage, restore
- [ ] **6.6** ADR-0005: bootstrap secrets vs runtime secrets
- [ ] **6.7** (optional) SSH CA: short-lived SSH certificates instead of `authorized_keys`

### 7. Ingress traffic and proxies
- [ ] **7.1** Oracle NLB → Oracle workers (Terraform)
- [ ] **7.2** Gateway API: Envoy Gateway or Traefik (ingress-nginx is retired)
- [ ] **7.3** Xray VLESS+Reality: TCP passthrough, keys from Vault, Oracle only (`nodeSelector`, multi-arch)
- [ ] **7.4** Second proxy (UDP), keys from Vault
- [ ] **7.5** Test from an external client

### 8. Monitoring
- [ ] **8.1** kube-prometheus-stack: cluster and node metrics
- [ ] **8.2** Proxy metrics: proxy vs VPN load on dashboards
- [ ] **8.3** GCP e2-micro: external Uptime Kuma — monitoring the monitoring
- [ ] **8.4** Alertmanager → Telegram

### 9. Operations — break and fix
Every breakage gets a runbook in `docs/runbooks/`: symptom → hypothesis → check → cause → fix.
- [ ] **9.1** etcd backup to OCI, break it, restore
- [ ] **9.2** Shut down 1 master — still alive; 2 — not, see why
- [ ] **9.3** `drain`/`cordon`, take a node out and back
- [ ] **9.4** Cluster version upgrade
- [ ] **9.5** Pods: Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled
- [ ] **9.6** Break DNS — fix it
- [ ] **9.7** Break MTU — fix it
- [ ] **9.8** Kill a Vault replica, unseal after restart

### 10. Showcase
- [ ] **10.1** README: diagram, "why this way", links to ADRs and runbooks
- [ ] **10.2** `terraform destroy` → `apply` → Ansible: cluster from scratch out of git, measure the time
- [ ] **10.3** Prep notes: "let me share my screen" walkthrough of this repository

## Backlog
- Quota checks as code: `data "oci_limits_resource_availability"` + `check` blocks (A1 cores = 2, memory = 12) — catch "apply succeeded but the result is wrong"

## Risks
- Oracle: "out of capacity" on A1 → fallback: workers on AWS credits
- **Oracle, 2026-12-17 — end of trial:** if A1 totals > 2 OCPU / 12 GB, ALL A1 instances are disabled and deleted after 30 days; Object Storage over 20 GB is deleted. By that date — no more than 2/12
- **Oracle idle reclamation:** an Always Free VM whose 95th percentile CPU, network and memory are < 20% over 7 days may be reclaimed. Options: Pay As You Go (per the community it is not reclaimed, not confirmed in docs) — decide before 2026-12-17
- GCP: the cluster lives ~90 days → everything in Terraform, step 10.2 is mandatory. **Extension:** before GCP expires — migrate the control plane to AWS on the live cluster (join a master in AWS → remove a GCP master, ×3; etcd keeps quorum). AWS credits (~$120–200) last ~2–3.5 months for 3 masters
- Free tier terms change (Oracle cut A1 in June 2026) — recheck at sign-up
- vps1 is both a worker and the relay host: firewall changes must not close 8443
