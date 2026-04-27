#!/bin/bash
###############################################################################
# scripts/setup-github-secrets.sh
# Helper script to configure GitHub repository secrets for CI/CD pipeline
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Repository owner and name
#   - OCI credentials and SSH key
#
# Usage:
#   ./setup-github-secrets.sh <owner>/<repo>
#
# Example:
#   ./setup-github-secrets.sh nathansnts/open-claw
###############################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_error() {
  echo -e "${RED}✗${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $*"
}

usage() {
  cat <<EOF
Usage: $0 <owner>/<repo>

Sets up GitHub repository secrets for the OpenClaw infrastructure pipeline.

Example:
  $0 nathansnts/open-claw

Required secrets:
  - OCI_CLI_TENANCY          OCID of OCI tenancy
  - OCI_CLI_USER             OCID of OCI user
  - OCI_CLI_FINGERPRINT      Fingerprint of OCI API key
  - OCI_CLI_KEY_CONTENT      PEM-encoded OCI private key
  - OCI_CLI_REGION           OCI region (e.g., sa-saopaulo-1)
  - OCI_BUCKET_NAME          Object Storage bucket for Terraform state
  - OCI_COMPARTMENT_ID       OCID of OCI compartment
  - SSH_PUBLIC_KEY           Public SSH key for instance access
  - SSH_PRIVATE_KEY          Private SSH key for validation checks
  - ALLOWED_CIDR             CIDR range for SSH/HTTPS access

EOF
  exit 1
}

check_requirements() {
  # Check if gh CLI is installed
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    echo "Install from: https://cli.github.com"
    exit 1
  fi

  # Check if authenticated
  if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
  fi

  log_success "GitHub CLI is installed and authenticated"
}

prompt_for_secret() {
  local secret_name="$1"
  local description="$2"
  local is_sensitive="${3:-false}"

  if [[ "$is_sensitive" == "true" ]]; then
    read -s -p "Enter $description ($secret_name): " secret_value
    echo ""
  else
    read -p "Enter $description ($secret_name): " secret_value
  fi

  echo "$secret_value"
}

set_secret() {
  local repo="$1"
  local secret_name="$2"
  local secret_value="$3"

  if echo "$secret_value" | gh secret set "$secret_name" --repo "$repo" 2>/dev/null; then
    log_success "Set $secret_name"
  else
    log_error "Failed to set $secret_name"
    return 1
  fi
}

load_from_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    log_warn "File not found: $file_path"
    return 1
  fi

  cat "$file_path"
}

main() {
  local repo="${1:-}"

  if [[ -z "$repo" ]]; then
    log_error "Repository argument is required"
    usage
  fi

  log_info "Setting up GitHub secrets for repository: $repo"
  echo ""

  # Verify repository exists
  if ! gh repo view "$repo" &> /dev/null; then
    log_error "Repository not found or access denied: $repo"
    exit 1
  fi

  log_success "Repository verified"
  echo ""

  # Check requirements
  check_requirements
  echo ""

  # Interactive secret configuration
  log_info "=== OCI Provider Authentication Secrets ==="
  echo ""

  OCI_CLI_TENANCY=$(prompt_for_secret "OCI_CLI_TENANCY" "OCI Tenancy OCID" true)
  set_secret "$repo" "OCI_CLI_TENANCY" "$OCI_CLI_TENANCY"

  OCI_CLI_USER=$(prompt_for_secret "OCI_CLI_USER" "OCI User OCID" true)
  set_secret "$repo" "OCI_CLI_USER" "$OCI_CLI_USER"

  OCI_CLI_FINGERPRINT=$(prompt_for_secret "OCI_CLI_FINGERPRINT" "OCI API Key Fingerprint" true)
  set_secret "$repo" "OCI_CLI_FINGERPRINT" "$OCI_CLI_FINGERPRINT"

  OCI_CLI_REGION=$(prompt_for_secret "OCI_CLI_REGION" "OCI Region (e.g., sa-saopaulo-1)" false)
  set_secret "$repo" "OCI_CLI_REGION" "$OCI_CLI_REGION"

  log_warn "For OCI_CLI_KEY_CONTENT, provide the path to your private key file:"
  read -p "Path to OCI private key file (e.g., ~/.oci/oci_api_key.pem): " oci_key_path
  if [[ -f "$oci_key_path" ]]; then
    OCI_CLI_KEY_CONTENT=$(cat "$oci_key_path")
    set_secret "$repo" "OCI_CLI_KEY_CONTENT" "$OCI_CLI_KEY_CONTENT"
  else
    log_error "OCI private key file not found: $oci_key_path"
    exit 1
  fi

  echo ""
  log_info "=== Infrastructure Secrets ==="
  echo ""

  OCI_BUCKET_NAME=$(prompt_for_secret "OCI_BUCKET_NAME" "Object Storage Bucket Name" false)
  set_secret "$repo" "OCI_BUCKET_NAME" "$OCI_BUCKET_NAME"

  OCI_COMPARTMENT_ID=$(prompt_for_secret "OCI_COMPARTMENT_ID" "OCI Compartment OCID" true)
  set_secret "$repo" "OCI_COMPARTMENT_ID" "$OCI_COMPARTMENT_ID"

  ALLOWED_CIDR=$(prompt_for_secret "ALLOWED_CIDR" "CIDR for SSH/HTTPS access (e.g., 203.0.113.0/24)" true)
  set_secret "$repo" "ALLOWED_CIDR" "$ALLOWED_CIDR"

  echo ""
  log_info "=== SSH Key Secrets ==="
  echo ""

  log_warn "For SSH_PUBLIC_KEY, provide the path to your public key file:"
  read -p "Path to SSH public key file (e.g., ~/.ssh/id_ed25519.pub): " ssh_pub_path
  if [[ -f "$ssh_pub_path" ]]; then
    SSH_PUBLIC_KEY=$(cat "$ssh_pub_path")
    set_secret "$repo" "SSH_PUBLIC_KEY" "$SSH_PUBLIC_KEY"
  else
    log_error "SSH public key file not found: $ssh_pub_path"
    exit 1
  fi

  log_warn "For SSH_PRIVATE_KEY (deployment validation), provide the path to your private key file:"
  read -p "Path to SSH private key file (e.g., ~/.ssh/id_ed25519): " ssh_priv_path
  if [[ -f "$ssh_priv_path" ]]; then
    SSH_PRIVATE_KEY=$(cat "$ssh_priv_path")
    set_secret "$repo" "SSH_PRIVATE_KEY" "$SSH_PRIVATE_KEY"
  else
    log_error "SSH private key file not found: $ssh_priv_path"
    exit 1
  fi

  echo ""
  log_success "=== All secrets configured successfully ==="
  echo ""
  log_info "Repository secrets:"
  gh secret list --repo "$repo" | grep -E "(OCI|SSH|ALLOWED)" || true
  echo ""
  log_info "Next steps:"
  log_info "1. Create an environment 'production' in GitHub: Settings → Environments → New environment"
  log_info "2. Add required reviewers to the 'production' environment"
  log_info "3. Run the infrastructure pipeline when ready"
}

main "$@"
