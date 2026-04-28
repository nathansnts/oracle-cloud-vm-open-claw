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

  validation {
    condition     = length(var.allowed_cidr) > 0
    error_message = "A variável allowed_cidr está VAZIA. O GitHub Actions não conseguiu ler o secret. Certifique-se de que o nome no 'Repository Secrets' é exatamente OCI_ALLOWED_CIDR e não ALLOWED_CIDR."
  }

  validation {
    condition     = length(var.allowed_cidr) == 0 || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.allowed_cidr))
    error_message = "A variável allowed_cidr tem um FORMATO INVÁLIDO. O valor deve ser um bloco CIDR puro, por exemplo '187.19.0.0/16' (sem espaços no final, sem comentários e com a máscara /16 ou /32)."
  }
}

variable "tags" {
  description = "Freeform tags applied to all network resources."
  type        = map(string)
  default     = {}
}
