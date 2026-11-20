# firewall

An iptables firewall for a VPS running k3s.

## Why our own chain instead of a full ruleset

k3s, flannel and kube-proxy keep their own iptables chains (`KUBE-*`,
`FLANNEL-*`, `CNI-*`). A full `iptables-restore` load would wipe them and break
cluster networking. So the role manages only the `FIREWALL-INPUT` chain:
it loads it with `iptables-restore --noflush` (atomically, in one transaction)
and puts a jump to it as the first rule of `INPUT`.

## Rules

| From                             | Allowed                          |
|----------------------------------|----------------------------------|
| `lo`, `wg0` (+ `cni0`, `flannel.1` on vps1) | everything             |
| internet                         | WireGuard `51820/udp`, ICMP      |
| replies to our own connections   | `ESTABLISHED,RELATED`            |
| anything else                    | `DROP`                           |

SSH is closed from outside: the host is reachable only through WireGuard.
Prometheus, node_exporter, Grafana and the k3s API are also reachable only
through `wg0`. IPv4 and IPv6 are handled the same way.

**Emergency access** when `wg0` is down — only the VPS provider's console.

## Lockout protection

1. The rules template is checked with `iptables-restore --test` before it is written to the server.
2. Before applying, a 5-minute rollback timer is armed with `systemd-run`.
3. The rules are applied, the current SSH connection is reset.
4. A new connection through `wg0` is tested.
5. If it succeeds, the timer is disarmed. If Ansible was cut off, after
   5 minutes the timer removes the jump to `FIREWALL-INPUT` and disables
   loading the rules at boot.
6. The control machine checks that port 22 on the public address is closed.

After a reboot the rules are loaded by `firewall.service` before networking comes up.

## Interaction with other services

On any rule change the role notifies `firewall changed`. The role knows nothing
about who listens: rebuilding the k3s chains is a handler in
`playbooks/firewall.yml`.

The k3s interfaces (`cni0`, `flannel.1`) are not in the role defaults — they are
set in `inventory/host_vars/vps1.yml`, where k3s actually runs.

## Limitations

- Services published through k3s ServiceLB (`hostPort`, Traefik on 80/443)
  go through DNAT in `PREROUTING` and `FORWARD`, not through `INPUT`. This role
  does not close them.
- The `FORWARD` chain is left alone — k3s manages it.
- The closed-SSH check only uses the IPv4 address from
  `ansible_facts['default_ipv4']`.

## Variables

| Variable                      | Default                          |
|-------------------------------|----------------------------------|
| `firewall_chain`              | `FIREWALL-INPUT`                 |
| `firewall_trusted_interfaces` | `lo`, `wg0`                      |
| `firewall_public_tcp_ports`   | `[]`                             |
| `firewall_public_udp_ports`   | `[51820]`                        |
| `firewall_ipv6`               | `true`                           |
| `firewall_rollback_timeout`   | `300`                            |
| `firewall_check_ssh_closed`   | `true`                           |
