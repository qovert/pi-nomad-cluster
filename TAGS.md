# Ansible Tags Reference

This document describes all available Ansible tags for selective deployment and testing.

## Usage Examples

```bash
# Deploy only the base system setup
ansible-playbook -i inventory/hosts.yml site.yml --tags "base"

# Install only Docker runtime
ansible-playbook -i inventory/hosts.yml site.yml --tags "docker"

# Deploy only Consul cluster
ansible-playbook -i inventory/hosts.yml site.yml --tags "consul"

# Deploy only Nomad orchestration
ansible-playbook -i inventory/hosts.yml site.yml --tags "nomad"

# Deploy only Traefik load balancer
ansible-playbook -i inventory/hosts.yml site.yml --tags "traefik"

# Deploy only code-server IDE
ansible-playbook -i inventory/hosts.yml site.yml --tags "code-server"

# Deploy only RocketChat
ansible-playbook -i inventory/hosts.yml site.yml --tags "rocketchat"

# Deploy all core infrastructure (skip applications)
ansible-playbook -i inventory/hosts.yml site.yml --tags "setup,cluster"

# Deploy all applications (skip infrastructure)
ansible-playbook -i inventory/hosts.yml site.yml --tags "jobs"

# Run only verification/testing tasks
ansible-playbook -i inventory/hosts.yml site.yml --tags "verify,test"
```

## Role-Level Tags

### Core Roles
- `base` - Base system setup and packages
- `docker` - Docker container runtime
- `consul` - Service discovery and health checking
- `nomad` - Container orchestration
- `jobs` - Application deployment

### Functional Categories
- `setup` - Initial system configuration
- `packages` - Package installation
- `cluster` - Multi-node clustering components
- `services` - Service management and startup
- `apps` - Application deployments

## Task-Level Tags

### Base Role
- `packages` - Install essential system packages
- `time` - Configure NTP time synchronization
- `directories` - Create base directory structure
- `storage` - Storage and filesystem setup

### Docker Role
- `prerequisites` - Install Docker repository prerequisites
- `repository` - Add Docker package repositories
- `keys` - Manage GPG keys and security
- `install` - Install Docker packages
- `users` - Configure user permissions
- `permissions` - Docker socket and group permissions
- `service` - Start and enable Docker service
- `verify` - Test Docker functionality

### Consul Role
- `hashicorp` - HashiCorp repository and keys
- `install` - Install Consul package
- `security` - Gossip encryption and security
- `encryption` - Cluster encryption keys
- `config` - Consul configuration files
- `service` - Start and enable Consul service

### Nomad Role
- `install` - Install Nomad package
- `networking` - Network configuration and CNI
- `cni` - Container Network Interface plugins
- `plugins` - Network and runtime plugins
- `download` - Download external components
- `directories` - Create Nomad directories
- `storage` - Persistent storage setup
- `volumes` - Host volume configuration
- `config` - Nomad configuration files
- `service` - Start and enable Nomad service

### Jobs Role

#### Traefik Load Balancer
- `traefik` - All Traefik-related tasks
- `loadbalancer` - Load balancing functionality
- `template` - Generate job templates
- `plan` - Plan deployment changes
- `deploy` - Execute deployments
- `status` - Check deployment status  
- `verify` - Health verification
- `health` - Health checks
- `stop` - Stop/remove deployments
- `force` - Force operations
- `migration` - Job type migrations
- `inspect` - Inspect existing jobs

#### Code-Server IDE
- `code-server` - All code-server tasks
- `ide` - IDE functionality
- `template` - Generate templates
- `plan` - Plan deployments
- `deploy` - Execute deployments

#### RocketChat Collaboration
- `rocketchat` - All RocketChat tasks
- `chat` - Chat functionality
- `collaboration` - Team collaboration
- `template` - Generate templates
- `plan` - Plan deployments
- `deploy` - Execute deployments

#### Test Services
- `hello` - Hello world test service
- `test` - Testing functionality
- `debug` - Debug services
- `template` - Test templates
- `plan` - Test planning
- `deploy` - Test deployments

## Advanced Tag Combinations

### Infrastructure Only
```bash
ansible-playbook site.yml --tags "base,docker,consul,nomad" --skip-tags "jobs"
```

### Applications Only
```bash
ansible-playbook site.yml --tags "jobs" --skip-tags "base,docker,consul,nomad"
```

### Security Components
```bash
ansible-playbook site.yml --tags "security,encryption,keys,permissions"
```

### Network Components
```bash
ansible-playbook site.yml --tags "networking,cni,plugins"
```

### Service Management
```bash
ansible-playbook site.yml --tags "service,start"
```

### Configuration Updates
```bash
ansible-playbook site.yml --tags "config,template"
```

### Testing and Verification
```bash
ansible-playbook site.yml --tags "verify,test,health,debug"
```

### Deployment Operations
```bash
ansible-playbook site.yml --tags "deploy,plan,status"
```

## Skip Patterns

### Skip Testing
```bash
ansible-playbook site.yml --skip-tags "test,debug,verify"
```

### Skip Heavy Downloads
```bash
ansible-playbook site.yml --skip-tags "download,plugins"
```

### Skip Application Deployments
```bash
ansible-playbook site.yml --skip-tags "traefik,code-server,rocketchat,hello"
```

### Skip Service Restarts
```bash
ansible-playbook site.yml --skip-tags "service,start"
```

## Development Workflows

### Quick Development Setup
```bash
# Install infrastructure
ansible-playbook site.yml --tags "base,docker,consul,nomad"

# Deploy only Traefik for testing
ansible-playbook site.yml --tags "traefik"

# Test with hello service
ansible-playbook site.yml --tags "hello" --extra-vars "deploy_test_services=true"
```

### Production Deployment
```bash
# Full production deployment
ansible-playbook site.yml --skip-tags "test,debug,hello"

# Or explicitly production services
ansible-playbook site.yml --tags "base,docker,consul,nomad,traefik,code-server"
```

### Troubleshooting
```bash
# Verify infrastructure health
ansible-playbook site.yml --tags "verify,health,test"

# Redeploy specific service
ansible-playbook site.yml --tags "traefik,deploy"

# Check configurations
ansible-playbook site.yml --tags "config,template" --check
```

## Tag Inheritance

- Role tags are inherited by all tasks in that role
- Multiple tags can be applied to single tasks
- Tasks can be selected by any matching tag
- Use `--list-tags` to see all available tags
- Use `--list-tasks` to see what tasks would run

## Best Practices

1. **Use specific tags** for targeted operations
2. **Combine tags** for logical groupings
3. **Test with --check** before actual deployment
4. **Use --list-tasks** to preview operations
5. **Document custom tag combinations** for your workflows