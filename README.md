# HashiCorp Nomad + Consul + Docker Cluster

An Ansible playbook for deploying a production-ready HashiCorp Nomad and Consul cluster with Docker container orchestration.

## Architecture

- **3-node cluster** (can be adjusted)
- **Consul**: Service discovery, health checking, and configuration management
- **Nomad**: Container orchestration and job scheduling
- **Docker**: Container runtime with proper security configuration
- **Traefik**: Reverse proxy and load balancer with automatic HTTPS

## Prerequisites

### Infrastructure Requirements

- **3+ Linux hosts** (tested on Raspberry Pi 5 with Debian 12/Bookworm, adaptable to other distros)
- **Shared storage path** (default: `/tank` - adjust `zfs_pool_root` variable for different paths)
- **Network connectivity** between all nodes
- **SSH access** with sudo privileges

### Control Machine Requirements

- **Ansible 2.14+**
- **Required collections**:

  ```bash
  ansible-galaxy collection install community.general
  ansible-galaxy collection install ansible.posix  # optional, for extended system management
  ```

### DNS/Certificate Requirements (Optional)

- **DNS provider API access** for automatic HTTPS certificates (currently supports Hetzner DNS)
- **Domain name** for web services

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml` to match your environment:

```yaml
all:
  hosts:
    node1:
      ansible_host: 192.168.1.10
      ansible_user: your_user
    node2:
      ansible_host: 192.168.1.11
      ansible_user: your_user
    node3:
      ansible_host: 192.168.1.12
      ansible_user: your_user
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

### 2. Configure Variables

Copy and customize the configuration:

```bash
cp group_vars/all.yml.example group_vars/all.yml
```

**Key settings to update:**

- `consul_retry_join`: List of all node IPs
- `cluster_domain`: Your domain name (if using HTTPS)
- `zfs_pool_root`: Storage path (change from `/tank` if needed)

### 3. Set Secrets (Optional - for HTTPS)

If you want automatic HTTPS certificates:

```bash
# Create encrypted vault file
ansible-vault create group_vars/all.yml

# Or edit existing vault
ansible-vault edit group_vars/all.yml

# Required secrets for HTTPS:
# - hetzner_api_key: "your-dns-api-token"
# - acme_contact_email: "your-email@domain.com"
```

### 4. Deploy the Cluster

```bash
# With vault password prompt (if using secrets)
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

# Without vault (HTTP-only setup)
ansible-playbook -i inventory/hosts.yml site.yml
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

## What Gets Deployed

The playbook will:

1. **Base Setup**: Install essential tools and create storage directories
2. **Docker Installation**: Install Docker CE with security configurations
3. **Consul Cluster**: 3-server cluster with gossip encryption and service discovery
4. **Nomad Cluster**: Server+client on all nodes with Docker driver and disabled problematic drivers
5. **Sample Applications**: Traefik reverse proxy and a "hello world" web app

## Post-Installation DNS Setup (Optional)

For HTTPS-enabled web services, create DNS records pointing to your cluster:

- **A/AAAA Record**: `hello.[your-domain]` → Load balancer IP or primary node
- **CNAME Record**: `*.apps.[your-domain]` → Primary node (for additional services)

**Note**: With DNS-01 ACME challenges, your cluster doesn't need to be publicly accessible on port 80 for certificate issuance.

## Accessing Services After Installation

### **Consul UI**

- **URL**: `http://[node-ip]:8500` (accessible from any cluster node)
- **Features**: Service discovery, health checks, key-value store
- **Security**: No authentication by default (enable ACLs for production)

### **Nomad UI**

- **URL**: `http://[node-ip]:4646` (accessible from any cluster node)
- **Features**: Job management, allocation monitoring, resource utilization
- **Security**: No authentication by default (enable ACLs for production)

### **Sample Application**

- **URL**: `https://hello.[your-domain]` or `http://[primary-node-ip]` with Host header
- **Description**: Sample "hello world" app demonstrating the complete stack
- **Load Balancer**: Traefik reverse proxy (pinned to first node by default)

### **Service Discovery**

All services register with Consul and are discoverable at:

- **Consul DNS**: `<service>.service.consul` (port 8600)
- **HTTP API**: `http://[node-ip]:8500/v1/catalog/services`

## Management and Monitoring

### **Useful Commands**

```bash
# Check cluster status
ssh [user]@[node-ip] "consul members"
ssh [user]@[node-ip] "nomad node status"

# View running jobs
ssh [user]@[node-ip] "nomad job status"

# Check service health
ssh [user]@[node-ip] "consul catalog services"

# Test sample application
curl -H "Host: hello.local" http://[primary-node-ip]/
```

### **Driver Status**

The playbook configures Nomad with optimized driver settings:

- ✅ **docker**: Primary container runtime
- ✅ **raw_exec**: For direct binary execution
- ❌ **exec**: Disabled (cgroup compatibility issues)
- ❌ **java**: Disabled (cgroup compatibility issues)

### **Security Considerations**

This deployment prioritizes functionality and ease of setup. For production:

- **Enable Consul ACLs**: `consul acl bootstrap`
- **Enable Nomad ACLs**: Configure in `nomad.hcl`
- **TLS encryption**: Enable mTLS between services
- **Network security**: Use firewalls and VPNs
- **Secret management**: Use Vault or external secret stores

## Customization

### **Scaling**

- **Add nodes**: Update inventory and `consul_retry_join` list
- **Remove nodes**: Ensure cluster maintains odd number of servers
- **Multi-region**: Configure additional datacenters

### **Storage**

- **Different paths**: Modify `zfs_pool_root` in variables
- **External storage**: Configure additional `nomad_host_volumes`
- **Backup**: Implement Consul snapshot automation

### **Load Balancing**

- **High Availability**: Set `traefik_run_on_all_nodes: true`
- **External LB**: Use keepalived, HAProxy, or cloud load balancers
- **Multiple domains**: Configure additional Traefik routers

## Troubleshooting

### **Common Issues**

```bash
# Check system requirements
df -h /tank  # Verify storage path exists
systemctl status docker consul nomad

# View service logs
journalctl -u consul -f
journalctl -u nomad -f

# Debug job failures
nomad alloc status [allocation-id]
nomad alloc logs [allocation-id]
```

### **Driver Issues**

If you see unhealthy exec/java drivers (expected):

- These are disabled by design due to cgroup compatibility
- Docker driver handles all container workloads
- No action needed unless you specifically need these drivers

## Contributing

This playbook is designed to be modular and extensible:

1. **Fork the repository**
2. **Test changes** with `ansible-playbook --check`
3. **Update documentation** for any configuration changes
4. **Submit pull requests** with clear descriptions

## License

MIT License - see LICENSE file for details.
