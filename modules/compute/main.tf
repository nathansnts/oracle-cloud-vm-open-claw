###############################################################################
# modules/compute/main.tf
# Provisions an OCI Compute instance with cloud-init for OpenClaw.
###############################################################################

# ---------- Lookup latest Ubuntu 24.04 LTS image -------------------------
data "oci_core_images" "ubuntu_2404" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "state"
    values = ["AVAILABLE"]
  }
}

# ---------- Cloud-init template ------------------------------------------
data "cloudinit_config" "openclaw" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-init.yaml")
    filename     = "cloud-init.yaml"
  }
}

# ---------- Compute Instance ---------------------------------------------
resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = var.instance_display_name
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_2404.images[0].id
    # Boot volume uses Oracle defaults (size & type) — no customization.
  }

  create_vnic_details {
    subnet_id                 = var.subnet_id
    assign_public_ip          = true
    display_name              = "${var.instance_display_name}-vnic"
    hostname_label            = var.instance_hostname_label
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.openclaw.rendered
  }

  freeform_tags = var.tags

  # Prevent accidental destruction of a running instance.
  lifecycle {
    prevent_destroy = false
  }
}
