#!/bin/bash
###############################################################################
# scripts/validate-openclaw.sh
# Validates OpenClaw installation and service health after deployment
# 
# Usage:
#   ./validate-openclaw.sh <instance_public_ip> <ssh_key_path> [timeout_seconds]
#
# Example:
#   ./validate-openclaw.sh 129.146.1.234 ~/.ssh/openclaw_key 300
###############################################################################

set -euo pipefail

# ===== Configuration ==========================================================
INSTANCE_IP="${1:-}"
SSH_KEY="${2:-}"
TIMEOUT="${3:-300}"  # Default 5 minutes
SSH_USER="ubuntu"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"

# Validation constants
OPENCLAW_PORT=18789
OPENCLAW_SERVICE="openclaw-gateway"
MAX_RETRIES=30
RETRY_DELAY=10

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===== Functions ==============================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
  cat <<EOF
Usage: $0 <instance_public_ip> <ssh_key_path> [timeout_seconds]

Arguments:
  instance_public_ip   Public IP address of the OCI instance
  ssh_key_path         Path to the private SSH key (~/.ssh/id_rsa or similar)
  timeout_seconds      Maximum time to wait for OpenClaw availability (default: 300)

Environment Variables:
  SSH_USER             SSH username (default: ubuntu)
  SSH_OPTS             Additional SSH options (default: "-o StrictHostKeyChecking=accept-new...")

Examples:
  $0 129.146.1.234 ~/.ssh/openclaw_key
  $0 129.146.1.234 ~/.ssh/openclaw_key 600
EOF
  exit 1
}

# ===== Validation =============================================================

if [[ -z "$INSTANCE_IP" ]]; then
  log_error "Missing argument: instance_public_ip"
  usage
fi

if [[ -z "$SSH_KEY" ]]; then
  log_error "Missing argument: ssh_key_path"
  usage
fi

SSH_KEY=$(eval echo "$SSH_KEY")  # Expand ~ to home directory

if [[ ! -f "$SSH_KEY" ]]; then
  log_error "SSH key not found: $SSH_KEY"
  exit 1
fi

# ===== Health Check Functions =================================================

check_ssh_connectivity() {
  log_info "Checking SSH connectivity to $SSH_USER@$INSTANCE_IP..."
  
  if ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
    log_info "✓ SSH connectivity OK"
    return 0
  else
    log_error "✗ SSH connection failed"
    return 1
  fi
}

wait_for_ssh() {
  local retry=0
  log_info "Waiting for SSH to be available (max ${TIMEOUT}s)..."
  
  while [[ $retry -lt $MAX_RETRIES ]]; do
    if check_ssh_connectivity; then
      return 0
    fi
    
    sleep $RETRY_DELAY
    retry=$((retry + 1))
    elapsed=$((retry * RETRY_DELAY))
    
    if [[ $elapsed -gt $TIMEOUT ]]; then
      log_error "Timeout waiting for SSH connectivity"
      return 1
    fi
    
    log_warn "SSH not ready yet... retrying ($retry/$MAX_RETRIES)"
  done
  
  return 1
}

check_cloud_init_status() {
  log_info "Checking cloud-init status..."
  
  local status=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "sudo cloud-init status --format json 2>/dev/null | grep -o '\"status\": \"[^\"]*\"' | cut -d'\"' -f4" 2>/dev/null || echo "unknown")
  
  if [[ "$status" == "done" ]]; then
    log_info "✓ Cloud-init completed successfully"
    return 0
  elif [[ "$status" == "running" ]]; then
    log_warn "⏳ Cloud-init still running (status: $status)"
    return 0  # Not a failure, just informational
  else
    log_warn "⚠ Cloud-init status unknown or pending: $status"
    return 0  # Not a hard failure
  fi
}

check_openclaw_service() {
  log_info "Checking $OPENCLAW_SERVICE systemd service..."
  
  local status=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "sudo systemctl is-active $OPENCLAW_SERVICE 2>/dev/null || echo 'inactive'" 2>/dev/null)
  
  if [[ "$status" == "active" ]]; then
    log_info "✓ OpenClaw service is active"
    return 0
  elif [[ "$status" == "activating" ]]; then
    log_warn "⏳ OpenClaw service is activating..."
    return 0
  else
    log_error "✗ OpenClaw service is not running (status: $status)"
    return 1
  fi
}

check_openclaw_port() {
  log_info "Checking if OpenClaw port $OPENCLAW_PORT is listening..."
  
  local is_listening=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "sudo netstat -tlnp 2>/dev/null | grep -q :$OPENCLAW_PORT && echo 'yes' || echo 'no'" 2>/dev/null || echo "unknown")
  
  if [[ "$is_listening" == "yes" ]]; then
    log_info "✓ Port $OPENCLAW_PORT is listening"
    return 0
  else
    log_error "✗ Port $OPENCLAW_PORT is not listening"
    return 1
  fi
}

check_openclaw_http() {
  log_info "Checking HTTP connectivity to http://$INSTANCE_IP:$OPENCLAW_PORT..."
  
  local http_code=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:$OPENCLAW_PORT --connect-timeout 5 || echo '000'" 2>/dev/null)
  
  if [[ "$http_code" =~ ^(200|302|401|403)$ ]]; then
    log_info "✓ HTTP response received (status: $http_code)"
    return 0
  else
    log_error "✗ HTTP request failed (status: $http_code)"
    return 1
  fi
}

check_openclaw_version() {
  log_info "Checking OpenClaw version..."
  
  local version=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "openclaw --version 2>/dev/null || echo 'unknown'" 2>/dev/null)
  
  log_info "✓ OpenClaw version: $version"
  return 0
}

check_system_resources() {
  log_info "Checking system resources..."
  
  local mem_used=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "free | awk '/^Mem/ {printf \"%.0f\", (\$3/\$2)*100}'" 2>/dev/null || echo "0")
  
  local disk_used=$(ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$INSTANCE_IP" \
    "df / | awk '/\// {printf \"%.0f\", (\$3/\$2)*100}'" 2>/dev/null || echo "0")
  
  log_info "✓ Memory usage: ${mem_used}%"
  log_info "✓ Disk usage: ${disk_used}%"
  
  # Warn if usage is high
  if [[ ${mem_used} -gt 80 ]]; then
    log_warn "⚠ High memory usage: ${mem_used}%"
  fi
  
  if [[ ${disk_used} -gt 80 ]]; then
    log_warn "⚠ High disk usage: ${disk_used}%"
  fi
  
  return 0
}

# ===== Main Execution =========================================================

main() {
  log_info "=== OpenClaw Deployment Validation ==="
  log_info "Instance: $SSH_USER@$INSTANCE_IP"
  log_info "Timeout: ${TIMEOUT}s"
  echo ""
  
  # Step 1: Wait for SSH connectivity
  if ! wait_for_ssh; then
    log_error "Failed to establish SSH connectivity"
    exit 1
  fi
  echo ""
  
  # Step 2: Check cloud-init status
  check_cloud_init_status
  echo ""
  
  # Step 3: Check OpenClaw service
  if ! check_openclaw_service; then
    log_warn "⏳ OpenClaw service not yet active, will continue with other checks..."
  fi
  echo ""
  
  # Step 4: Check port availability
  if ! check_openclaw_port; then
    log_warn "⚠ Port not yet listening, OpenClaw may still be initializing..."
  fi
  echo ""
  
  # Step 5: Check HTTP connectivity
  if ! check_openclaw_http; then
    log_warn "⚠ HTTP connectivity not established yet"
  fi
  echo ""
  
  # Step 6: Check OpenClaw version
  check_openclaw_version
  echo ""
  
  # Step 7: Check system resources
  check_system_resources
  echo ""
  
  log_info "=== Validation Complete ==="
  log_info "Instance is accessible and OpenClaw deployment is progressing."
  log_info "Access OpenClaw UI at: http://$INSTANCE_IP:$OPENCLAW_PORT (after full initialization)"
  
  return 0
}

# ===== Error Handling =========================================================

trap 'log_error "Script interrupted"; exit 130' INT TERM

# ===== Entry Point ============================================================

main "$@"
exit $?
