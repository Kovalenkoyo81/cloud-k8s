# 0003. Terraform state в OCI Object Storage

**Статус:** принято, блокировку проверить

## Контекст

State должен пережить облака, которыми управляет: GCP и AWS здесь временные (кредиты). Варианты: бакет в одном из облаков, GitLab-managed state, HCP Terraform.

## Решение

S3-backend, указывающий на S3-совместимый API OCI Object Storage (Always Free, бессрочно). Блокировка — `use_lockfile = true` (нативная, Terraform ≥ 1.10, без DynamoDB). Бакет создаёт отдельная конфигурация `terraform/bootstrap/` с локальным state.

## Последствия

- State не зависит от временных облаков.
- Нужна проверка: поддерживает ли API OCI условную запись (`If-None-Match`), на которой держится блокировка. Тест — два параллельных `terraform plan`.
- Если не поддерживает — переход на GitLab-managed state.
