###############################################################################
# environments/production/locals.tf
# Centralizes tags, naming conventions, and reusable derived values.
###############################################################################

locals {
  # -- Project metadata (DRY: referenced by all modules) ---
  project     = "openclaw"
  environment = "production"

  # -- Common freeform tags applied to every resource ---
  common_tags = {
    project     = local.project
    environment = local.environment
    managed_by  = "terraform"
    repository  = "open-claw"
  }

  # -- Naming prefix for display names ---
  name_prefix = "${local.project}-${local.environment}"
}
