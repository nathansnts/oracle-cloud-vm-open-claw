###############################################################################
# environments/production/outputs.tf
# Expose key information after apply.
###############################################################################

output "instance_public_ip" {
  description = "Public IP of the OpenClaw compute instance."
  value       = module.compute.instance_public_ip
}

output "instance_id" {
  description = "OCID of the compute instance."
  value       = module.compute.instance_id
}

output "instance_private_ip" {
  description = "Private IP of the compute instance."
  value       = module.compute.instance_private_ip
}

output "instance_state" {
  description = "Lifecycle state of the instance."
  value       = module.compute.instance_state
}

output "vcn_id" {
  description = "OCID of the VCN."
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = module.network.public_subnet_id
}

output "image_id" {
  description = "OCID of the Ubuntu 24.04 LTS image used."
  value       = module.compute.image_id
}

output "ssh_connect_command" {
  description = "SSH command to connect to the instance."
  value       = "ssh ubuntu@${module.compute.instance_public_ip}"
}

output "openclaw_ui_url" {
  description = "URL for the OpenClaw Control UI (accessible after cloud-init completes)."
  value       = "http://${module.compute.instance_public_ip}:18789"
  sensitive = true
}
