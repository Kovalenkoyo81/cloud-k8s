# 0004. NetBox as the source of truth for inventory

**Status:** accepted

## Context

Nodes appear and disappear through Terraform in three clouds. A static `hosts.yml` drifts from reality with every change.

## Decision

When Terraform creates a VM, it registers it in NetBox (site, role, IP). Ansible takes hosts from NetBox via `netbox.netbox.nb_inventory`. NetBox runs in Docker on the operator's machine — outside the cluster it describes.

## Consequences

- A new node in Terraform is immediately visible to Ansible by role — no manual inventory edits.
- CI cannot reach NetBox: CI runs only fmt/validate/lint; `plan` and playbook runs happen from the operator's machine.
- The NetBox database is the source of truth: a regular `pg_dump` is mandatory.
