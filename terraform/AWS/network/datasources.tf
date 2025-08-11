locals {
    name_prefix = "${var.env}-${var.project_name}"

    # Default tags
    default_tags = {
        Environment = var.env
        Project     = var.project_name
        ManagedBy   = "Terraform"
    }
}