###############################################################################
# environments/production/checks.tf
# Infrastructure validation checks executed after apply
# Validates that deployed resources meet expected conditions
# Reference: https://developer.hashicorp.com/terraform/language/checks
###############################################################################

# ---------- Instance Availability Check -----------------------------------
check "instance_is_running" {
  assert {
    condition = (
      oci_core_instance.this.state == "RUNNING"
    )
    error_message = format(
      "Compute instance is not in RUNNING state. Current state: %s",
      oci_core_instance.this.state
    )
  }
}

# ---------- Network Connectivity Check ------------------------------------
check "instance_has_public_ip" {
  assert {
    condition = (
      module.compute.instance_public_ip != null &&
      module.compute.instance_public_ip != ""
    )
    error_message = "Compute instance does not have a public IP address assigned."
  }
}

# ---------- VCN Routing Check -----------------------------------------------
check "vcn_has_internet_access" {
  assert {
    condition = (
      length(module.network.public_subnet_id) > 0
    )
    error_message = "Public subnet is not properly configured for internet access."
  }
}

# ---------- Security Configuration Check ----------------------------------
check "security_list_configured" {
  assert {
    condition = (
      module.network.security_list_id != null &&
      module.network.security_list_id != ""
    )
    error_message = "Security list is not properly configured."
  }
}

# ---------- Tags Applied Check ---------------------------------------------
check "resources_have_required_tags" {
  assert {
    condition = (
      lookup(oci_core_instance.this.freeform_tags, "project", null) == "openclaw" &&
      lookup(oci_core_instance.this.freeform_tags, "environment", null) == "production" &&
      lookup(oci_core_instance.this.freeform_tags, "managed_by", null) == "terraform"
    )
    error_message = "Compute instance does not have required freeform tags applied."
  }
}
