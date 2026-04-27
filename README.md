# OpenClaw — OCI Infrastructure (Terraform)

Production-ready Terraform solution to provision OpenClaw on Oracle Cloud Infrastructure (OCI).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     OCI Tenancy                         │
│                                                         │
│  ┌───────────────── VCN (10.0.0.0/16) ───────────────┐  │
│  │                                                     │  │
│  │  ┌── Internet Gateway ──┐                          │  │
│  │  │    0.0.0.0/0 → IGW   │                          │  │
│  │  └──────────┬───────────┘                          │  │
│  │             │                                       │  │
│  │  ┌──────────▼────────── Public Subnet ───────────┐ │  │
│  │  │  10.0.1.0/24                                   │ │  │
│  │  │                                                │ │  │
│  │  │  ┌─────────────────────────────────┐          │ │  │
│  │  │  │  VM.Standard.E4.Flex            │          │ │  │
│  │  │  │  2 OCPUs · 8 GB RAM             │          │ │  │
│  │  │  │  Ubuntu 24.04 LTS               │          │ │  │
│  │  │  │  ┌─────────────────────────┐    │          │ │  │
│  │  │  │  │  OpenClaw Gateway       │    │          │ │  │
│  │  │  │  │  :18789 (UI)            │    │          │ │  │
│  │  │  │  └─────────────────────────┘    │          │ │  │
│  │  │  └─────────────────────────────────┘          │ │  │
│  │  │                                                │ │  │
│  │  │  Security List:                                │ │  │
│  │  │    IN  → TCP/22  from ALLOWED_CIDR             │ │  │
│  │  │    IN  → TCP/443 from ALLOWED_CIDR             │ │  │
│  │  │    OUT → ALL to 0.0.0.0/0                      │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
.
├── .github/workflows/
│   ├── infra-apply.yml          # CI/CD: lint → plan → approve → apply → validate
│   └── infra-destroy.yml        # CI/CD: confirm → approve → destroy
├── scripts/
│   ├── validate-openclaw.sh     # Post-deployment validation script
│   └── setup-github-secrets.sh  # Helper to configure GitHub secrets
├── modules/
│   ├── network/
│   │   ├── main.tf              # VCN, IGW, Route Table, Security List, Subnet
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── compute/
│       ├── main.tf              # Compute instance + cloud-init
│       ├── variables.tf
│       ├── outputs.tf
│       └── cloud-init.yaml      # OS update, OpenClaw install, ufw
├── environments/production/
│   ├── main.tf                  # Root module (wires network + compute)
│   ├── variables.tf             # All input variables
│   ├── outputs.tf               # Exposed outputs (IPs, OCIDs, URLs)
│   ├── locals.tf                # Tags, naming conventions
│   ├── checks.tf                # Infrastructure validation checks
│   ├── versions.tf              # Provider pinning, remote state backend
│   └── terraform.tfvars.example # Template for variable values
├── VALIDATION.md                # Post-deployment validation documentation
├── .gitignore
└── README.md
```

## Prerequisites

1. **OCI Account** with a compartment and sufficient quotas
2. **OCI API Key** configured for your user ([docs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm))
3. **Terraform** >= 1.14.0 installed locally
4. **OCI Object Storage Bucket** for remote state (created once):
   ```bash
   oci os bucket create \
     --name openclaw-tfstate \
     --compartment-id <your-compartment-ocid> \
     --versioning Enabled
   ```
5. **SSH Key Pair** (generate if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "openclaw-prod" -f ~/.ssh/openclaw_ed25519 -N ""
   ```

## Quick Start (Local)

```bash
# 1. Navigate to the production environment
cd environments/production

# 2. Create your tfvars from the example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values

# 3. Initialize Terraform (configure backend)
terraform init \
  -backend-config="bucket=openclaw-tfstate" \
  -backend-config="region=us-ashburn-1" \
  -backend-config="endpoint=https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"

# 4. Preview changes
terraform plan -out=tfplan

# 5. Apply
terraform apply tfplan

# 6. Connect to the instance
ssh ubuntu@$(terraform output -raw instance_public_ip)

# 7. Monitor cloud-init progress
sudo tail -f /var/log/cloud-init-openclaw.log

# 8. Access OpenClaw UI (after cloud-init completes)
echo "http://$(terraform output -raw instance_public_ip):18789"
```

## CI/CD Pipeline (GitHub Actions)

### Apply Workflow (`infra-apply.yml`)

Triggers on push/PR to `main` when infrastructure files change.

| Stage | Job | Description |
|-------|-----|-------------|
| 1 | Lint & Validate | `terraform fmt -check` + `terraform validate` |
| 2 | Security Scan | `tfsec` static analysis (SAST) |
| 3 | Plan | `terraform plan -out=tfplan` |
| 4 | Approve | Manual gate via GitHub Environment (`production`) |
| 5 | Apply | `terraform apply tfplan` + Terraform checks validation |
| 6 | Validate | Post-deployment health checks via `scripts/validate-openclaw.sh` |

### Destroy Workflow (`infra-destroy.yml`)

Manual trigger only (`workflow_dispatch`). Requires:
1. Typed confirmation: input must be exactly `DESTROY`
2. Environment approval: `production` environment reviewers

### Required GitHub Secrets

#### OCI Authentication (Terraform Apply)
| Secret | Description |
|--------|-------------|
| `OCI_CLI_USER` | OCID of the OCI user for API auth |
| `OCI_CLI_TENANCY` | OCID of the OCI tenancy |
| `OCI_CLI_FINGERPRINT` | Fingerprint of the API signing key |
| `OCI_CLI_KEY_CONTENT` | PEM private key content (multi-line, sensitive) |
| `OCI_CLI_REGION` | OCI region identifier (e.g. `us-ashburn-1`) |
| `OCI_BUCKET_NAME` | Object Storage bucket name for remote state |
| `OCI_COMPARTMENT_ID` | OCID of OCI compartment |

#### Infrastructure & Deployment
| Secret | Description |
|--------|-------------|
| `SSH_PUBLIC_KEY` | Public SSH key for instance access (Terraform) |
| `SSH_PRIVATE_KEY` | **NEW** - Private SSH key for post-deployment validation |
| `ALLOWED_CIDR` | CIDR range allowed for SSH/HTTPS ingress |

#### Quick Setup
Use the automated setup script to configure all secrets:
```bash
chmod +x scripts/setup-github-secrets.sh
./scripts/setup-github-secrets.sh nathansnts/open-claw
```

Or set manually:
```bash
gh secret set SSH_PRIVATE_KEY --repo nathansnts/open-claw < ~/.ssh/openclaw_ed25519
```

Additionally, these variables must be set:
- `TF_VAR_compartment_id` — add as a repository variable or secret
- `TF_VAR_availability_domain` — add as a repository variable or secret

### GitHub Environment Setup

1. Go to **Settings → Environments → New environment**
2. Name it `production`
3. Enable **Required reviewers** and add your team
4. Optionally restrict to the `main` branch

## Security Checklist

- [x] All credentials passed via `sensitive = true` variables or environment variables
- [x] SSH key injected via variable — never embedded in code
- [x] Security List follows least-privilege: only ports 22 and 443 from a specific CIDR
- [x] Egress is unrestricted (required for package installs and updates)
- [x] No hardcoded OCIDs, keys, or passwords in any file
- [x] `.gitignore` excludes `*.tfvars`, `*.tfstate`, SSH keys, and `.terraform/`
- [x] Remote state stored in OCI Object Storage (encrypted at rest)
- [x] CI/CD pipeline includes `tfsec` security scanning
- [x] Destroy workflow requires typed confirmation + environment approval
- [x] Provider versions pinned to prevent supply-chain drift

## Post-Deployment Verification

### Automated Validation (CI/CD)
The pipeline automatically validates the deployment in the **Validate OpenClaw Deployment** stage:
- SSH connectivity to instance
- Cloud-init completion status
- OpenClaw service health
- Port availability and HTTP response
- System resource utilization

See [VALIDATION.md](VALIDATION.md) for detailed validation documentation.

### Manual Verification
```bash
# SSH into the instance
ssh ubuntu@<public-ip>

# Check cloud-init status
sudo cloud-init status --long

# Review OpenClaw installation log
sudo cat /var/log/cloud-init-openclaw.log

# Verify OpenClaw service
sudo systemctl status openclaw-gateway

# Verify firewall rules
sudo ufw status

# Test OpenClaw health
curl http://localhost:18789
```

### Local Validation Script
```bash
# Requires SSH key and network access to instance
./scripts/validate-openclaw.sh <instance-public-ip> ~/.ssh/openclaw_ed25519 [timeout-seconds]

# Example with 10-minute timeout
./scripts/validate-openclaw.sh 129.146.1.234 ~/.ssh/openclaw_ed25519 600
```

## Cleanup

```bash
# Local destroy
cd environments/production
terraform destroy

# Or use the CI/CD destroy workflow (recommended)
# Go to Actions → "Infrastructure — Destroy" → Run workflow → Type "DESTROY"
```

## Cost Notes

- **VM.Standard.E4.Flex** with 2 OCPUs / 8 GB: check current pricing at [OCI Pricing](https://www.oracle.com/cloud/pricing/)
- Boot volume uses Oracle default size (no additional storage costs)
- No Load Balancer or NAT Gateway provisioned
- Consider OCI Always Free shapes (VM.Standard.A1.Flex, VM.Standard.E2.1.Micro) for development

## License

See repository root for license information.
