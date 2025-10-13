# Pi Cluster: Nomad + Consul + Podman (Raspberry Pi 5 / Bookworm)

## Prereqs
- SSH access as `pi` (or set `ansible_user` in inventory)
- ZFS pool mounted at `/tank`
- Ansible 2.14+ on your control machine
- Collections: `ansible-galaxy collection install community.general`

Optional (convenience):
`ansible-galaxy collection install ansible.posix` and `containers.podman` if you extend later.

## Configure inventory
Edit `inventory/hosts.yml` and `group_vars/all.yml` as needed.

Store secrets with Ansible Vault:
```bash
ansible-vault edit group_vars/all.yml  # set hetzner_api_key, acme_contact_email
```

## Run
```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

This will:
1. Install base tools and create `/tank` subdirs.
2. Install Podman and enable the Docker-compatible socket.
3. Install and configure Consul (3-server cluster, gossip encryption).
4. Install and configure Nomad (server+client on all nodes, Podman driver).
5. Deploy Traefik ingress (ACME via Hetzner DNS) pinned to `pistor0` and a "hello" sample app.

### DNS
Create an A/AAAA record (or reverse proxy/LB) for `hello.{{ cluster_domain }}` pointing to where 80/443 reach `pistor0` (or your VIP if you later add keepalived). With DNS-01, the ACME DNS challenge works via Hetzner API; public reachability on :80 isn't required for issuance.

## Notes / Next steps
- Turn on ACLs and TLS for Consul/Nomad when ready.
- If you want failover later, run Traefik on `pistor1` as a backup and add keepalived for a floating VIP.
- Add Consul DNS forwarding via `dnsmasq` if you want `.consul` lookups from the Pis.
