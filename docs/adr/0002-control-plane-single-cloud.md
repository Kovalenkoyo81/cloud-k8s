# 0002. Control plane in a single cloud, workers anywhere

**Status:** accepted

## Context

Nodes live in three clouds and on a VPS. etcd commits a write once a majority confirms it (Raft): with tens of milliseconds of latency between members, write latency grows and spurious leader elections happen. kubelet tolerates latency to the API server.

## Decision

Three masters (etcd ×3) in one GCP region (Madrid), in different zones. Workers in Oracle, AWS and on the VPS, connected over WireGuard.

## Consequences

- Quorum survives the loss of one master or one zone, but not of the whole GCP region.
- Control plane lifetime is limited by GCP credits (~90 days) — the cluster must be rebuildable from code.
- No provider's Always Free tier offers three VMs with 2 GB RAM for the masters.
