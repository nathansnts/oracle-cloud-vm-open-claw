#!/bin/bash
###############################################################################
# tests/post_deployment.tftest.hcl
# Terraform test cases for post-deployment infrastructure validation
# Reference: https://developer.hashicorp.com/terraform/language/tests
#
# Run tests with:
#   terraform test
#
# This file contains test blocks that validate infrastructure assumptions
# AFTER resources are provisioned but before practical usage tests.
###############################################################################

variables {
  # Override defaults if needed
}

run "setup" {
  # Initial setup step - can be used to validate inputs
  command = plan
}

run "instance_provisioned" {
  # Validate that the compute instance is created
  command = apply

  assert {
    condition     = oci_core_instance.this.state == "RUNNING"
    error_message = "Compute instance should be in RUNNING state"
  }

  assert {
    condition     = oci_core_instance.this.public_ip != null && oci_core_instance.this.public_ip != ""
    error_message = "Instance should have a public IP assigned"
  }
}

run "network_configured" {
  # Validate network infrastructure
  command = apply

  assert {
    condition     = module.network.vcn_id != null && module.network.vcn_id != ""
    error_message = "VCN should be created and have an ID"
  }

  assert {
    condition     = module.network.public_subnet_id != null && module.network.public_subnet_id != ""
    error_message = "Public subnet should be created"
  }

  assert {
    condition     = module.network.internet_gateway_id != null && module.network.internet_gateway_id != ""
    error_message = "Internet Gateway should be created"
  }

  assert {
    condition     = module.network.security_list_id != null && module.network.security_list_id != ""
    error_message = "Security List should be created"
  }
}

run "resource_tags_applied" {
  # Validate that required tags are applied
  command = apply

  assert {
    condition = (
      lookup(oci_core_instance.this.freeform_tags, "project", null) == "openclaw" &&
      lookup(oci_core_instance.this.freeform_tags, "environment", null) == "production" &&
      lookup(oci_core_instance.this.freeform_tags, "managed_by", null) == "terraform"
    )
    error_message = "Instance should have required freeform tags"
  }
}

run "vcn_cidr_validation" {
  # Validate VCN CIDR configuration
  command = apply

  assert {
    condition     = length(oci_core_vcn.this.cidr_blocks) > 0
    error_message = "VCN should have at least one CIDR block"
  }

  assert {
    condition     = oci_core_vcn.this.cidr_blocks[0] == var.vcn_cidr
    error_message = "VCN CIDR should match configured value"
  }
}

run "subnet_cidr_validation" {
  # Validate subnet configuration
  command = apply

  assert {
    condition     = oci_core_subnet.public.cidr_block == var.subnet_cidr
    error_message = "Subnet CIDR should match configured value"
  }

  assert {
    condition     = oci_core_subnet.public.prohibit_public_ip_on_vnic == false
    error_message = "Public subnet should allow public IPs"
  }
}
