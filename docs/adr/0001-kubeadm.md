# 0001. kubeadm wrapped in our own Ansible roles

**Status:** accepted

## Context

The cluster has to be installed reproducibly, as code. Ready-made options: kubespray (a large set of Ansible roles), k3s/RKE2 ("all-in-one" distributions), kubeadm (the official tool, bootstraps the control plane only).

## Decision

kubeadm wrapped in our own roles: `base` (node preparation) and `kubernetes` (packages, init, join).

## Consequences

- Every step is visible and understood: kernel modules, sysctl, containerd, certificates, control plane join — no "magic" from someone else's playbook.
- More work than kubespray; upgrades and HA details are on me.
- k3s rejected: SQLite/embedded etcd and its simplifications hide exactly what has to be operated.
