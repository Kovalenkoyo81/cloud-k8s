# admin_user

An administration user, and root login locked down.

- creates `admin_user_name` (default `devops`) in the `sudo` group;
  sudo requires a password; the password and its hash live in vault, per host
- adds public keys from `admin_user_authorized_keys` (appended to the existing
  ones, not replacing them — so access from other machines is not cut off)
- `/etc/ssh/sshd_config.d/10-hardening.conf`: password login disabled,
  root over SSH disabled; the config is checked with `sshd -t` before writing
- after the reload a new connection is tested

## Self-lockout protection

While Ansible connects as root, root cannot be disabled completely — the role
would lock itself out. In that case `PermitRootLogin prohibit-password` is set
(root by key only). Full lockdown happens on the next run, already as
`admin_user_name`.

First run on a host that only has root:

```bash
ansible-playbook playbooks/access.yml --limit <host> -e ansible_user=root
ansible-playbook playbooks/access.yml --limit <host>      # now as devops
```

## Variables

| Variable                     | Default          |
|------------------------------|------------------|
| `admin_user_name`            | `devops`         |
| `admin_user_groups`          | `[sudo]`         |
| `admin_user_authorized_keys` | `[]`             |
| `admin_user_password_hash`   | unset — the password is not changed |
