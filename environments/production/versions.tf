###############################################################################
# environments/production/versions.tf
# Pin provider and Terraform versions for reproducible builds.
###############################################################################

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.10.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }

  # ---------- Remote State — OCI Object Storage (native backend) -----------
  # The bucket must already exist. Create it once via OCI Console or CLI:
  #   oci os bucket create --name <bucket> --compartment-id <compartment-ocid>
  # Requires Terraform >= 1.12. Uses ~/.oci/config for authentication.
  backend "oci" {
    bucket    = "vm-state"
    namespace = "grrmxpv8wi49"
    key       = "production/terraform.tfstate"
    region    = "sa-saopaulo-1"

    # Uses OCI CLI config for auth (API Key from ~/.oci/config)
    auth                = "APIKey"
    config_file_profile = "DEFAULT"
  }
}
