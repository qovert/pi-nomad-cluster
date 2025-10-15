# HashiCorp Nomad + Consul Cluster

Production-ready Ansible playbook for deploying a HashiCorp Nomad and Consul cluster with secure bridge networking and service discovery.

## Architecture

- **Multi-node cluster** with HA Consul and Nomad
- **Bridge networking** with CNI plugins for container isolation  
- **Service discovery** via Consul with health checking
- **Load balancing** with Traefik ingress gateway
- **Secure TLS** with self-signed certificates for internal use
- **Persistent storage** with host volume mounting

## Components

- **Consul 1.21.5**: Service discovery and health checking
- **Nomad 1.10.5**: Container orchestration and job scheduling  
- **Docker CE 28.5**: Container runtime
- **Traefik v3.0**: Ingress gateway and load balancer
- **CNI Plugins v1.3.0**: Container network interface for bridge networking

## Prerequisites

- **Linux hosts** (tested on Raspberry Pi 5/Debian 12, adaptable to other distros)
- **Storage path** (default: `/tank` - configurable via `zfs_pool_root`)
- **Network connectivity** between all nodes
- **SSH access** with sudo privileges
- **Ansible 2.14+** on control machine

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  hosts:
    node1:
      ansible_host: 192.168.1.10
      ansible_user: your_user
    # Add additional nodes...
```

### 2. Configure Variables

```bash
cp group_vars/all.yml.example group_vars/all.yml
# Edit with your settings using ansible-vault for secrets:
ansible-vault edit group_vars/all.yml

# Configure:
# - consul_retry_join: [list of node IPs]  
# - cluster_domain: your.domain.com
# - clus_env: production|staging|development
# - code_server_password: !vault |
#     $ANSIBLE_VAULT;1.1;AES256
#     [encrypted password]
```

### 3. Deploy Cluster

```bash
# Production deployment (idempotent)
ansible-playbook -i inventory/hosts.yml site.yml

# With encrypted variables
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

## Configuration

### Deployment Controls

Set in `group_vars/all.yml` (use `ansible-vault edit` for secrets):

```yaml
# Environment controls
deploy_test_services: false     # Enable debug/test services
deploy_code_server: true        # Deploy VS Code server
deploy_rocketchat: false        # Deploy RocketChat team collaboration
clus_env: production            # Environment type

# Deployment behavior
verify_deployments: false       # Wait and verify health after deployment
traefik_run_on_all_nodes: true  # Run Traefik on all nodes vs pistor0 only

# Encrypted secrets (use ansible-vault)
code_server_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  66386439653364336464643234633863636366643534643738386435663632643938633939336638
  3830393566636631393835323030643361373838373465650a373934366665623838326164613434
  [truncated encrypted content]
```

## Run

### With Ansible Vault (Recommended)

```bash
# Interactive vault password prompt
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

# Using vault password file (more secure for automation)
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook -i inventory/hosts.yml site.yml --vault-password-file ~/.vault_pass

# Edit encrypted variables
ansible-vault edit group_vars/all.yml --vault-password-file ~/.vault_pass
```

### Selective Deployment with Tags

The playbook includes comprehensive tagging for selective deployment:

```bash
# Deploy only infrastructure (skip applications)
ansible-playbook site.yml --tags "base,docker,consul,nomad"

# Deploy only Traefik load balancer
ansible-playbook site.yml --tags "traefik"

# Deploy only code-server IDE
ansible-playbook site.yml --tags "code-server"

# Deploy only RocketChat
ansible-playbook site.yml --tags "rocketchat"

# Run verification/health checks only
ansible-playbook site.yml --tags "verify,health"

# See all available tags
ansible-playbook site.yml --list-tags
```

See [TAGS.md](TAGS.md) for complete tag reference and advanced usage examples.

## What Gets Deployed

The playbook will:

1. **Base Setup**: Install essential tools and create storage directories
2. **Docker Installation**: Install Docker CE with security configurations
3. **Consul Cluster**: 3-server cluster with gossip encryption and service discovery

### Web Interfaces

- **Consul UI**: `http://[node-ip]:8500` - Service discovery and health checks
- **Nomad UI**: `http://[node-ip]:4646` - Job management and monitoring  
- **Traefik Dashboard**: `http://[node-ip]:8080` - Load balancer status

### Deployment Resilience

The playbook includes several improvements to prevent deployment hangs and increase reliability:

- **Detached deployments**: Jobs deploy with `--detach` to prevent hanging on health checks
- **Timeout controls**: 30-second limits on deployment commands
- **Conflict handling**: Graceful handling of "Cancelled due to newer version" errors
- **Job type migration**: Automatically handles service↔system job type changes
- **Health verification**: Optional post-deployment health checks (set `verify_deployments: true`)

**Quick Status Check**:

```bash
# Run comprehensive deployment status check
./scripts/check-deployments.sh

# Manual checks
nomad job status traefik
nomad alloc logs $(nomad job allocs traefik | tail -1 | awk '{print $1}') traefik
```

**Troubleshooting Job Type Conflicts**:
If you get "cannot update job from type X to Y" errors, the playbook automatically handles this by stopping and purging the existing job. For manual intervention:

```bash
# Force stop and restart Traefik
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass -e force_stop_traefik=true

# Or manually stop the job
nomad job stop -purge traefik
# Then run the playbook normally
```

### Services (with TLS)

- **Code-server**: `https://code.[your-domain]` - VS Code in browser
- **Test services**: `https://hello.[your-domain]` (if `deploy_test_services: true`)

## Adding New Services

### 1. Create Job Template

Create a new template in `roles/jobs/templates/`:

```hcl
# roles/jobs/templates/myapp.nomad.j2
job "myapp" {
  datacenters = ["{{ consul_datacenter }}"]
  type = "service"

  group "app" {
    network {
      mode = "bridge"
      port "http" { to = 8080 }
    }

    task "server" {
      driver = "docker"
      config {
        image = "myapp:latest"
        ports = ["http"]
      }

      service {
        name = "myapp"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.myapp.rule=Host(`myapp.{{ cluster_domain }}`)",
          "traefik.http.routers.myapp.tls=true"
        ]
      }
    }
  }
}
```

### 2. Add Template Rendering

Add to `roles/jobs/tasks/main.yml`:

```yaml
- name: Render MyApp job file
  ansible.builtin.template:
    src: myapp.nomad.j2
    dest: "{{ zfs_pool_root }}/nomad/jobs/myapp.nomad"
    mode: '0644'
    owner: nomad
    group: nomad
  when: deploy_myapp | default(true)

- name: Check if MyApp job needs updates
  ansible.builtin.command: nomad job plan "{{ zfs_pool_root }}/nomad/jobs/myapp.nomad"
  register: myapp_plan
  failed_when: false
  changed_when: false
  when: deploy_myapp | default(true)

- name: Deploy MyApp job
  ansible.builtin.command: nomad job run "{{ zfs_pool_root }}/nomad/jobs/myapp.nomad"
  register: myapp_submit
  changed_when: myapp_plan.rc == 1
  failed_when: myapp_submit.rc != 0 and myapp_plan.rc != 0
  when: deploy_myapp | default(true) and myapp_plan.rc != 0
```

### 3. Deploy

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

## Management

### Cluster Operations

```bash
# Check cluster health  
nomad node status
consul members

# View running services
nomad job status
consul catalog services

# Service logs
nomad alloc logs [allocation-id]

# Restart service
nomad job restart [job-name]
```

### Scaling Services

```bash
# Scale job replicas
nomad job scale [job-name] [count]

# Update job configuration  
nomad job run [job-file.nomad]
```

## Production Considerations

- **Enable ACLs**: Secure Consul and Nomad with access control lists
- **TLS encryption**: Enable mTLS between cluster components  
- **Network security**: Use firewalls and VPNs for cluster communication
- **Monitoring**: Deploy Prometheus, Grafana, or similar monitoring stack
- **Backup**: Implement Consul snapshot automation
- **Secrets**: Use HashiCorp Vault or external secret management

## License

MIT License - see LICENSE file for details.
