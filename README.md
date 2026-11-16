# cloud-k8s

Отказоустойчивый Kubernetes-кластер на бесплатных тарифах трёх облаков и собственного VPS. Всё, что можно, описано кодом: облака — Terraform, узлы — Ansible, кластер — манифесты.

```
                    Oracle NLB (L4)
                          │
   ┌──────────── WireGuard mesh ───────────────────────────┐
   │  GCP Madrid:     cp1  cp2  cp3   (kubeadm, etcd ×3)   │
   │  Oracle Madrid:  w-oci1  w-oci2  (arm64)              │
   │  AWS Spain:      w-aws1  (amd64)                      │
   │  VPS Madrid:     vps1    (amd64)                      │
   │  Calico VXLAN поверх WireGuard                        │
   └───────────────────────────────────────────────────────┘
```

## Структура

| Каталог | Что |
|---|---|
| `terraform/bootstrap/` | бакет для state (локальный state) |
| `terraform/modules/` | ВМ и сети по провайдерам, регистрация в NetBox |
| `terraform/envs/lab/` | корневая конфигурация: backend, провайдеры, вызов модулей |
| `ansible/` | подготовка узлов: WireGuard, base, kubeadm. Inventory — из NetBox |
| `k8s/platform/` | CNI, Gateway API, мониторинг |
| `k8s/apps/` | рабочие нагрузки |
| `docs/adr/` | архитектурные решения: почему так, а не иначе |

## Решения

- [0001 — kubeadm своими ролями](docs/adr/0001-kubeadm.md)
- [0002 — control plane в одном облаке](docs/adr/0002-control-plane-single-cloud.md)
- [0003 — Terraform state в OCI Object Storage](docs/adr/0003-terraform-state-oci.md)
- [0004 — NetBox как источник правды](docs/adr/0004-netbox-source-of-truth.md)
