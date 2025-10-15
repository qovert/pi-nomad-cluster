#!/bin/bash
# Deployment Status Checker
# Usage: ./scripts/check-deployments.sh

set -e

echo "=== Nomad Deployment Status Check ==="
echo

# Check if Nomad is available
if ! command -v nomad &> /dev/null; then
    echo "❌ Nomad command not found. Make sure Nomad is installed and in PATH."
    exit 1
fi

# Check Nomad leader
echo "📋 Checking Nomad cluster status..."
nomad server members || echo "❌ Failed to get server members"
echo

# Function to check job status
check_job_status() {
    local job_name=$1
    echo "🔍 Checking job: $job_name"
    
    if nomad job status "$job_name" &>/dev/null; then
        local status=$(nomad job status "$job_name" | grep "Status" | awk '{print $3}')
        local healthy=$(nomad job status "$job_name" | grep "Healthy" | awk '{print $3}')
        
        echo "   Status: $status"
        echo "   Healthy: $healthy"
        
        # Get allocation details
        local alloc_id=$(nomad job allocs "$job_name" | tail -n 1 | awk '{print $1}')
        if [ -n "$alloc_id" ] && [ "$alloc_id" != "ID" ]; then
            local alloc_status=$(nomad alloc status "$alloc_id" | grep "Status" | head -1 | awk '{print $3}')
            echo "   Last Allocation: $alloc_id ($alloc_status)"
            
            # Show recent events if allocation is not running
            if [ "$alloc_status" != "running" ]; then
                echo "   Recent Events:"
                nomad alloc status "$alloc_id" | grep -A 10 "Recent Events" | tail -n 5 | sed 's/^/     /'
            fi
        fi
    else
        echo "   ❌ Job not found or not deployed"
    fi
    echo
}

# Check common jobs
echo "🚀 Checking job deployments..."
echo

check_job_status "traefik"
check_job_status "hello"
check_job_status "code-server" 
check_job_status "rocketchat"

# Check Consul services
echo "🔧 Checking Consul services..."
if command -v consul &> /dev/null; then
    consul catalog services | while read service; do
        if [ "$service" != "consul" ]; then
            instances=$(consul catalog nodes -service="$service" | wc -l)
            echo "   $service: $((instances-1)) instances"
        fi
    done
else
    echo "   ❌ Consul command not available"
fi
echo

# Check connectivity to Traefik
echo "🌐 Checking Traefik connectivity..."
local_ip=$(hostname -I | awk '{print $1}')

if curl -s -o /dev/null -w "%{http_code}" "http://$local_ip:8080/ping"; then
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$local_ip:8080/ping")
    if [ "$response_code" = "200" ]; then
        echo "   ✅ Traefik dashboard reachable at http://$local_ip:8080"
        echo "   ✅ Traefik health check passing"
    else
        echo "   ⚠️  Traefik responding but health check returned: $response_code"
    fi
else
    echo "   ❌ Traefik not reachable at http://$local_ip:8080"
    echo "   💡 Try: nomad alloc logs \$(nomad job allocs traefik | tail -1 | awk '{print \$1}') traefik"
fi

echo
echo "=== Quick Commands ==="
echo "Monitor job: nomad job status <job-name>"
echo "View logs:   nomad alloc logs <alloc-id> <task-name>"
echo "Stop job:    nomad job stop <job-name>"
echo "Restart job: nomad job restart <job-name>"
echo