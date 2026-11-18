# План: HA-кластер Kubernetes в облаках free tier

Регион везде — Мадрид (рядом с vps1). Облака — Terraform, узлы — Ansible, кластер — манифесты.
Каждый шаг закрывается коммитом через PR, CI зелёный.

## Архитектура

```
                    Oracle NLB (free, L4)
                   443/tcp Xray · UDP второй прокси
                          │
   ┌──────────── WireGuard mesh (wg0 на всех нодах) ────────────┐
   │                                                            │
   │  GCP europe-southwest1:  cp1  cp2  cp3  (etcd ×3, kubeadm) │
   │                                                            │
   │  Oracle eu-madrid-1:  w-oci1  w-oci2  (arm64)  ← прокси,   │
   │                                                  Vault     │
   │  vps1:                worker (amd64) + рилей вне кластера  │
   │  AWS eu-south-2:      w-aws1 (amd64)                       │
   │                                                            │
   │  Calico VXLAN поверх wg0                                   │
   └────────────────────────────────────────────────────────────┘
   GCP e2-micro (US, always free): Uptime Kuma — внешний сторож
   Ноутбук: NetBox, Terraform, Ansible, Ansible Vault (bootstrap-секреты)
```

| Узел | Где | Ресурсы | Срок |
|---|---|---|---|
| cp1–cp3 | GCP, e2-small (2 vCPU / 2 GB) | $300 кредитов | ~90 дней с регистрации |
| w-oci1, w-oci2 | Oracle A1 (arm64), 1 OCPU / 6 GB каждый | Always Free (лимит 2 OCPU / 12 GB) | бессрочно |
| w-aws1 | AWS t3/t4g.small | кредиты Free plan | до 6 месяцев |
| vps1 | свой VPS, 2 vCPU / 4 GB | — | бессрочно |
| сторож | GCP e2-micro (US) | Always Free | бессрочно |

## Решения

- ✅ **kubeadm своими ролями** — [ADR-0001](docs/adr/0001-kubeadm.md)
- ✅ **Мастера в одном облаке (GCP), воркеры где угодно** — [ADR-0002](docs/adr/0002-control-plane-single-cloud.md)
- ✅ **Terraform state: S3-backend в OCI Object Storage, `use_lockfile`** — [ADR-0003](docs/adr/0003-terraform-state-oci.md). Не заработает блокировка → GitLab-managed state
- ✅ **NetBox на ноутбуке** — [ADR-0004](docs/adr/0004-netbox-source-of-truth.md)
- ✅ **Монорепо `cloud-k8s`**: `terraform/`, `ansible/`, `k8s/`, `docs/adr/`
- ✅ **Секреты в два слоя**: bootstrap (ключи WG, sudo, join) — Ansible Vault на ноутбуке; runtime (секреты подов) — HashiCorp Vault в кластере через External Secrets Operator

## Открытые решения
- Второй прокси: AmneziaWG (предложение: пара «прокси L7 + VPN L3») или Hysteria2 — решить до шага 7.4

---

## Этапы

### 0. Репозиторий и аккаунты
- [x] **0.1** `git init`, первый коммит, проверить что `GOAL.md`/`STATUS.md`/`CLAUDE.md` не попали в git
- [x] **0.2** Репозиторий на GitHub (публичный), push, CI зелёный
- [x] **0.3** Ruleset на `main`: только через PR, обязательные проверки CI
- [x] **0.4** Oracle: регистрация, **home region Madrid** (не меняется!)
- [x] **0.5** Oracle: проверить доступность `VM.Standard.A1.Flex` и квоты Always Free (A1, NLB, Object Storage, KMS)
- [x] **0.6** Oracle: Budget с алертом на почту при трате > $1
- [x] **0.7** AWS: регистрация, **Free plan**, MFA на root
- [x] **0.8** AWS: Budget (zero spend, кредиты исключены фильтром Charge type). Доступ Terraform → перенесён в 1.7
- [x] **0.9** GCP — **не регистрировать до шага 4.1** (90 дней кредитов стартуют с регистрации)

### 1. Terraform — фундамент
- [x] **1.1** OCI: compartment `cloud-k8s`, группа и пользователь `terraform` (только API key + Customer secret key), политика, `~/.oci/config` (профиль `cloud-k8s`), `~/.aws/credentials` (профиль `oci-cloud-k8s`)
- [ ] **1.2** `terraform/bootstrap/` (локальный state, не в git): провайдер `oci`, проверка доступа (namespace Object Storage)
- [ ] **1.3** bootstrap: квоты Always Free (`oci_limits_quota`): A1 ≤ 2 OCPU / 12 GB, остальные shapes ВМ = 0
- [ ] **1.4** bootstrap: бакет для state в OCI Object Storage (версионирование)
- [ ] **1.5** `terraform/envs/lab/`: S3-backend → OCI, `use_lockfile = true`
- [ ] **1.6** Тест блокировки: два параллельных `terraform plan` — второй падает на lock
- [ ] **1.7** Модуль `oci-worker`: VCN, subnet, security list (51820/udp + порты прокси), 2 × A1
- [ ] **1.8** AWS: включить opt-in регион eu-south-2; доступ Terraform через временные учётные данные (роль/сессия, не постоянные ключи); модуль `aws-worker`: VPC, security group, 1 ВМ
- [ ] **1.9** Outputs: имена, публичные и приватные IP

### 2. NetBox — источник правды
- [ ] **2.1** NetBox в Docker на ноутбуке, бэкап `pg_dump` по расписанию
- [ ] **2.2** Модель: сайты (gcp/oci/aws/vps), роли (`control-plane`, `worker`), теги
- [ ] **2.3** Модуль `netbox-host`: Terraform регистрирует ВМ в NetBox
- [ ] **2.4** Ansible `nb_inventory`: группы по роли и сайту, статического inventory нет
- [ ] **2.5** vps1 — в NetBox вручную или через Terraform (он не создаётся Terraform'ом)

### 3. Ansible — подготовка узлов
- [ ] **3.1** Роль `wireguard`: mesh между всеми узлами, ключи в Ansible Vault
- [ ] **3.2** Роль `base`: пользователи и SSH-харденинг (на основе `admin_user`)
- [ ] **3.3** Роль `base`: firewall (на основе `firewall`) — порты k8s, wg0 и интерфейсы Calico в доверенных
- [ ] **3.4** Роль `base`: swap off, модули `overlay`/`br_netfilter`, sysctl, containerd (`SystemdCgroup = true`), chrony
- [ ] **3.5** vps1: снести k3s и LocalStack (из homelab-infra), **рилей 8443 сохранить**

### 4. Kubernetes — control plane и узлы
- [ ] **4.1** GCP: регистрация, Budget $1, проект, сервисный аккаунт для Terraform
- [ ] **4.2** Модуль `gcp-control-plane`: 3 × e2-small в трёх зонах Мадрида
- [ ] **4.3** Роль `kubernetes`: kubeadm/kubelet/kubectl с пинами версий
- [ ] **4.4** Endpoint API: локальный haproxy на каждом узле → 3 мастера
- [ ] **4.5** `kubeadm init` на cp1 (`--control-plane-endpoint`, `EncryptionConfiguration` для Secret'ов в etcd)
- [ ] **4.6** Join cp2, cp3 как control plane; проверить кворум etcd
- [ ] **4.7** Join воркеров: Oracle (arm64), AWS и vps1 (amd64)
- [ ] **4.8** kubeconfig на ноутбук

### 5. Сеть кластера
- [ ] **5.1** Calico VXLAN поверх wg0, расчёт MTU (1500 → wg 1420 → vxlan 1370)
- [ ] **5.2** Проверка: под ↔ под между облаками, большой пакет проходит
- [ ] **5.3** NetworkPolicy: запрет трафика между namespace и проверка
- [ ] **5.4** StorageClass (local-path) для PVC

### 6. Секреты — HashiCorp Vault
- [ ] **6.1** OCI KMS: ключ для auto-unseal
- [ ] **6.2** Vault в кластере: Helm, 3 реплики, Raft, anti-affinity, auto-unseal через OCI KMS
- [ ] **6.3** Terraform-провайдер `vault`: policies, Kubernetes auth method, KV engine
- [ ] **6.4** External Secrets Operator: секрет из Vault → `Secret` в namespace
- [ ] **6.5** Снапшот Raft в OCI Object Storage, восстановление
- [ ] **6.6** ADR-0005: bootstrap-секреты vs runtime-секреты
- [ ] **6.7** (опционально) SSH CA: короткоживущие SSH-сертификаты вместо `authorized_keys`

### 7. Входящий трафик и прокси
- [ ] **7.1** Oracle NLB → воркеры Oracle (Terraform)
- [ ] **7.2** Gateway API: Envoy Gateway или Traefik (ingress-nginx заброшен)
- [ ] **7.3** Xray VLESS+Reality: TCP passthrough, ключи из Vault, только на Oracle (`nodeSelector`, multi-arch)
- [ ] **7.4** Второй прокси (UDP), ключи из Vault
- [ ] **7.5** Проверка с клиента снаружи

### 8. Мониторинг
- [ ] **8.1** kube-prometheus-stack: метрики кластера и узлов
- [ ] **8.2** Метрики прокси: нагрузка прокси vs VPN на графиках
- [ ] **8.3** GCP e2-micro: Uptime Kuma снаружи — мониторинг мониторинга
- [ ] **8.4** Alertmanager → Telegram

### 9. Эксплуатация — ломать и чинить
Каждая поломка — runbook в `docs/runbooks/`: симптом → гипотеза → проверка → причина → исправление.
- [ ] **9.1** Бэкап etcd в OCI, уронить, восстановить
- [ ] **9.2** Выключить 1 мастер — живёт; 2 — нет, увидеть почему
- [ ] **9.3** `drain`/`cordon`, вывод и возврат узла
- [ ] **9.4** Обновление версии кластера
- [ ] **9.5** Поды: Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled
- [ ] **9.6** Сломать DNS — починить
- [ ] **9.7** Сломать MTU — починить
- [ ] **9.8** Убить реплику Vault, распечатка после рестарта

### 10. Витрина
- [ ] **10.1** README: схема, «почему так», ссылки на ADR и runbook'и
- [ ] **10.2** `terraform destroy` → `apply` → Ansible: кластер с нуля из git, замерить время
- [ ] **10.3** PREP.md: заготовка «могу показать экран» под этот репозиторий

## Риски
- Oracle: «out of capacity» на A1 → запас: воркеры на AWS-кредитах
- **Oracle, 2026-12-17 — конец триала:** если на A1 в сумме > 2 OCPU / 12 GB, отключаются ВСЕ A1-инстансы и удаляются через 30 дней; Object Storage > 20 GB удаляется. К этой дате — не больше 2/12
- **Oracle idle reclamation:** Always Free ВМ с 95-м перцентилем CPU, сети и памяти < 20% за 7 дней может быть удалена. Варианты: Pay As You Go (по словам сообщества — не чистится, в документации не подтверждено) — решить до 2026-12-17
- GCP: кластер живёт ~90 дней → всё в Terraform, шаг 10.2 обязателен
- Условия free tier меняются (Oracle урезал A1 в июне 2026) — перепроверять при регистрации
- vps1 одновременно воркер и хост рилея: firewall-изменения не должны закрыть 8443
