###############################################################################
# environments/production/variables.tf
# All input variables for the production environment.
# Credentials are NEVER hardcoded — they come from env vars or CI secrets.
###############################################################################

# ---------- OCI Provider Authentication ----------------------------------

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCID of the OCI user for API key authentication."
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key."
  type        = string
  sensitive   = true
}

variable "private_key" {
  description = "PEM-encoded private key for OCI API authentication."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI region identifier (e.g. us-ashburn-1)."
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_id" {
  description = "OCID of the compartment for all resources."
  type        = string
}

# ---------- Network Configuration ----------------------------------------

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr" {
  description = "CIDR range permitted for inbound SSH and HTTPS access."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.allowed_cidr) > 0 && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.allowed_cidr))
    error_message = "O valor da variável allowed_cidr está vazio ou inválido. O plan falhou de propósito para evitar erro 400 no apply!"
  }
}

# ---------- Compute Configuration ----------------------------------------

variable "availability_domain" {
  description = "Availability Domain for the compute instance."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access. Never commit this value."
  type        = string
  sensitive   = true
}

variable "instance_shape" {
  description = "OCI compute shape."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for Flex shapes."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB for Flex shapes."
  type        = number
  default     = 8
}
