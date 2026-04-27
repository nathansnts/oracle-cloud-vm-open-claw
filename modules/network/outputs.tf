###############################################################################
# modules/network/outputs.tf
###############################################################################

output "vcn_id" {
  description = "OCID of the provisioned VCN."
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = oci_core_subnet.public.id
}

output "security_list_id" {
  description = "OCID of the public security list."
  value       = oci_core_security_list.public.id
}

output "internet_gateway_id" {
  description = "OCID of the Internet Gateway."
  value       = oci_core_internet_gateway.this.id
}
