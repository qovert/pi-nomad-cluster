# Pi Cluster: Nomad + Consul + Docker (Raspberry Pi 5 / Bookworm)

## Prereqs

- SSH access as `pi` (or set `ansible_user` in inventory)
- ZFS pool mounted at `/tank`
- Ansible 2.14+ on your control machine
- Collections: `ansible-galaxy collection install community.general`

Optional (convenience):
`ansible-galaxy collection install ansible.posix` for additional system management capabilities.

## Configure inventory and variables

1. **Edit inventory**: Update `inventory/hosts.yml` if needed (already configured for pistor0-2)

2. **Configure variables**: The main configuration is in `group_vars/all.yml` (encrypted with Ansible Vault)
   - See `group_vars/all.yml.example` for the plaintext template and documentation
   - Key settings: `cluster_domain`, `consul_retry_join`, `nomad_host_volumes`

3. **Set secrets with Ansible Vault**:
   ```bash
   # Edit the encrypted vault file to set real secrets
   ansible-vault edit group_vars/all.yml
   
   # Required secrets to update:
   # - hetzner_api_key: "your-hetzner-dns-api-token"
   # - acme_contact_email: "your-email@your-domain.us"
   ```

## Run

```bash
# Run with vault password prompt (recommended)
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

# Alternative: Use vault password file
# echo "your-vault-password" > ~/.ansible_vault_pass
# chmod 600 ~/.ansible_vault_pass
# ansible-playbook -i inventory/hosts.yml site.yml --vault-password-file ~/.ansible_vault_pass
```

This will:

1. Install base tools and create `/tank` subdirs.
2. Install Docker CE and configure for Nomad integration.
3. Install and configure Consul (3-server cluster, gossip encryption).
4. Install and configure Nomad (server+client on all nodes, Docker driver).
5. Deploy Traefik ingress (ACME via Hetzner DNS) pinned to `pistor0` and a "hello" sample app.

### DNS

Create an A/AAAA record (or reverse proxy/LB) for `hello.{{ cluster_domain }}` pointing to where 80/443 reach `pistor0` (or your VIP if you later add keepalived). With DNS-01, the ACME DNS challenge works via Hetzner API; public reachability on :80 isn't required for issuance.

## Accessing Services After Installation

### **Consul UI**

- **URL**: `http://172.16.30.30:8500` (or any node IP)
- **Features**: Service discovery, health checks, key-value store
- **Default**: No authentication (consider enabling ACLs for production)

### **Nomad UI**

- **URL**: `http://172.16.30.30:4646` (or any node IP)
- **Features**: Job management, allocation monitoring, resource utilization
- **Default**: No authentication (consider enabling ACLs for production)

### **Sample Application**

- **URL**: `https://hello.{{ cluster_domain }}` (e.g., `https://hello.qov.io`)
- **Description**: Sample "hello world" app demonstrating the complete stack
- **Load Balancer**: Traefik running on `pistor0`

### **Service Discovery**

All services register with Consul and are discoverable at:

- **Consul DNS**: `<service>.service.consul` (port 8600)
- **HTTP API**: `http://172.16.30.30:8500/v1/catalog/services`

### **Useful Commands**

```bash
# Check cluster status
ssh ditto@172.16.30.30 "consul members"
ssh ditto@172.16.30.30 "nomad node status"

# View running jobs
ssh ditto@172.16.30.30 "nomad job status"

# Check service health
ssh ditto@172.16.30.30 "consul catalog services"
```

## Notes / Next steps

- Turn on ACLs and TLS for Consul/Nomad when ready.
- If you want failover later, run Traefik on `pistor1` as a backup and add keepalived for a floating VIP.
- Add Consul DNS forwarding via `dnsmasq` if you want `.consul` lookups from the Pis.
