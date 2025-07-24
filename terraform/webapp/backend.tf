terraform {
    backend "s3" {
        bucket  = "my-vonq-demo"
        key     = "terraform.tfstate"
        region  = "eu-west-1"
        profile = "default"
        workspace_key_prefix = "terraform-state/webapp"
    }
}

provider "aws" {
    region  = var.aws_region
}