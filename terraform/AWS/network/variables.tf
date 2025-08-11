variable "project_name" {
    type = string
    description = "Prefix used in global naming convention"
    default = "vonq"
}

variable "env" {
    type = string
    description = "The workspace environment to deploy resource for"
}

variable "vpc_cidr_block" {
    type = string
    description = "Network CIDR for VPC"
}
