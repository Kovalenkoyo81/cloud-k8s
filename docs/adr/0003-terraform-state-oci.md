# 0003. Terraform state in OCI Object Storage

**Status:** accepted, locking to be verified

## Context

The state must outlive the clouds it manages: GCP and AWS are temporary here (credits). Options: a bucket in one of the clouds, GitLab-managed state, HCP Terraform.

## Decision

An S3 backend pointing at the S3-compatible API of OCI Object Storage (Always Free, no expiry). Locking via `use_lockfile = true` (native, Terraform ≥ 1.10, no DynamoDB). The bucket is created by a separate configuration, `terraform/bootstrap/`, with local state.

## Consequences

- The state does not depend on the temporary clouds.
- To verify: whether the OCI API supports conditional writes (`If-None-Match`), which locking relies on. Test: two parallel `terraform plan` runs.
- If it does not — switch to GitLab-managed state.
