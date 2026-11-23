# 0003. Terraform state in OCI Object Storage

**Status:** accepted, locking to be verified

## Context

The state must outlive the clouds it manages: GCP and AWS are temporary here (credits). Options: a bucket in one of the clouds, GitLab-managed state, HCP Terraform.

## Decision

The state is kept in OCI Object Storage (Always Free, no expiry) through the native `oci` backend (Terraform ≥ 1.12), one `key` per configuration (`bootstrap/terraform.tfstate`, `envs/lab/terraform.tfstate`).

- **Not the S3-compatible API.** Oracle marks it deprecated in favour of the native backend, and it needs a separate secret (Customer Secret Key) on top of the API key that the provider already uses. The native backend authenticates with the same `~/.oci/config` profile.
- **Locking** is built into the backend: before `plan`/`apply` it creates a `<key>.lock` object with `If-None-Match: *`, so a second run fails instead of overwriting the state.
- **Bootstrap** (`terraform/bootstrap/`) creates the bucket itself, so its state starts local and is then moved into that bucket with `terraform init -migrate-state`.

## Consequences

- The state does not depend on the temporary clouds.
- No credentials in the backend configuration; one secret (the API key) serves both the provider and the backend.
- To verify: whether OCI Object Storage honours `If-None-Match` as the backend expects. Test: two parallel `terraform plan` runs.
- If it does not — switch to GitLab-managed state.
- Rebuilding from scratch needs the bootstrap order: comment out the backend, apply with local state, restore the backend, migrate.
