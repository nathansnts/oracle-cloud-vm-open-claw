###############################################################################
# modules/compute/variables.tf
###############################################################################

variable "compartment_id" {
  description = "OCID of the compartment where the compute instance is created."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name for instance placement."
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet for the instance VNIC."
  type        = string
}

variable "instance_display_name" {
  description = "Display name for the compute instance."
  type        = string
  default     = "openclaw-instance"
}

variable "instance_hostname_label" {
  description = "Hostname label for the VNIC (alphanumeric, max 63 chars)."
  type        = string
  default     = "openclaw"
}

variable "instance_shape" {
  description = "OCI compute shape (e.g. VM.Standard.E4.Flex)."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for the Flex shape."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB for the Flex shape."
  type        = number
  default     = 8
}

variable "ssh_public_key" {
  description = "SSH public key injected into the instance for remote access."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Freeform tags applied to the compute instance."
  type        = map(string)
  default     = {}
}
