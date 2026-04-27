###############################################################################
# modules/network/variables.tf
###############################################################################

variable "compartment_id" {
  description = "OCID of the compartment where network resources are created."
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN (e.g. 10.0.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_display_name" {
  description = "Human-readable display name for the VCN."
  type        = string
  default     = "openclaw-vcn"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN (alphanumeric, max 15 chars)."
  type        = string
  default     = "openclawvcn"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_dns_label" {
  description = "DNS label for the public subnet (alphanumeric, max 15 chars)."
  type        = string
  default     = "pubsubnet"
}

variable "allowed_cidr" {
  description = "CIDR range allowed to access SSH (22) and HTTPS (443)."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Freeform tags applied to all network resources."
  type        = map(string)
  default     = {}
}
