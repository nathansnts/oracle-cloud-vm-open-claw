###############################################################################
# modules/compute/outputs.tf
###############################################################################

output "instance_id" {
  description = "OCID of the compute instance."
  value       = oci_core_instance.this.id
}

output "instance_public_ip" {
  description = "Public IP address of the compute instance."
  value       = oci_core_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the compute instance."
  value       = oci_core_instance.this.private_ip
}

output "instance_state" {
  description = "Current lifecycle state of the instance."
  value       = oci_core_instance.this.state
}

output "image_id" {
  description = "OCID of the Ubuntu 24.04 LTS image used."
  value       = data.oci_core_images.ubuntu_2404.images[0].id
}
