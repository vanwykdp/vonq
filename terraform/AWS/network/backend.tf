terraform {
    backend "s3" {
        bucket  = "my-vonq-demo"
        key     = "terraform.tfstate"
        region  = "eu-west-1"
        profile = "default"
        workspace_key_prefix = "terraform-state/network"
    }
}

provider "aws" {
    region  = "eu-west-1"
}