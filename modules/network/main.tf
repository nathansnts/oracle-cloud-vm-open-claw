###############################################################################
# modules/network/main.tf
# Provisions the core network fabric: VCN, IGW, Route Table, Security List,
# and a single public subnet.
###############################################################################

# ---------- VCN ----------------------------------------------------------
resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = var.vcn_display_name
  dns_label      = var.vcn_dns_label

  freeform_tags = var.tags
}

# ---------- Internet Gateway ---------------------------------------------
resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-igw"
  enabled        = true

  freeform_tags = var.tags
}

# ---------- Route Table (default route → IGW) ----------------------------
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }

  freeform_tags = var.tags
}

# ---------- Security List ------------------------------------------------
# Ingress: SSH (22) and HTTPS (443) restricted to the allowed CIDR.
# Egress:  Unrestricted (0.0.0.0/0) — required for package updates & installs.
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-public-sl"

  # --- Ingress rules (least-privilege) ---

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allowed_cidr
    source_type = "CIDR_BLOCK"
    description = "Allow SSH from trusted CIDR"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allowed_cidr
    source_type = "CIDR_BLOCK"
    description = "Allow HTTPS from trusted CIDR"
    stateless   = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # --- Egress rule (unrestricted) ---

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "Allow all outbound traffic"
    stateless        = false
  }

  freeform_tags = var.tags
}

# ---------- Public Subnet ------------------------------------------------
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.vcn_display_name}-public-subnet"
  dns_label                  = var.subnet_dns_label
  prohibit_public_ip_on_vnic = false # Public subnet
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]

  freeform_tags = var.tags
}
