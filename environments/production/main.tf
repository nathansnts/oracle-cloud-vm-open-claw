###############################################################################
# environments/production/main.tf
# Root module — wires the network and compute modules together.
###############################################################################

# ---------- OCI Provider Configuration -----------------------------------
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}

# ---------- Network Module -----------------------------------------------
module "network" {
  source = "../../modules/network"

  compartment_id   = var.compartment_id
  vcn_cidr         = var.vcn_cidr
  vcn_display_name = "${local.name_prefix}-vcn"
  vcn_dns_label    = "openclawprod"
  subnet_cidr      = var.subnet_cidr
  subnet_dns_label = "pubsubnet"
  allowed_cidr     = var.allowed_cidr
  tags             = local.common_tags
}

# ---------- Compute Module -----------------------------------------------
module "compute" {
  source = "../../modules/compute"

  compartment_id        = var.compartment_id
  availability_domain   = var.availability_domain
  subnet_id             = module.network.public_subnet_id
  instance_display_name = "${local.name_prefix}-instance"
  instance_hostname_label = "openclaw"
  instance_shape        = var.instance_shape
  instance_ocpus        = var.instance_ocpus
  instance_memory_gb    = var.instance_memory_gb
  ssh_public_key        = var.ssh_public_key
  tags                  = local.common_tags
}
