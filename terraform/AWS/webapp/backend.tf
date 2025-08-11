terraform {
    backend "s3" {
        bucket  = "darryl-vonq-terraform-state-test"
        key     = "terraform.tfstate"
        region  = "eu-west-1"
        profile = "default"
        workspace_key_prefix = "webapp"
    }
}

provider "aws" {
    region  = var.aws_region
}