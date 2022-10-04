variable "project_name" {
  type        = string
  default     = "Demo"
  description = "Project name for tagging purposes"
}

variable "environment" {
  type        = string
  default     = "Dev"
  description = "Environment name for tagging purposes"
}

variable "vpc" {
  type        = string
  description = "Comes from networking template"
}

variable "private_subnets" {
  type        = list
  description = "Comes from networking template"
}

variable "public_subnets" {
  type        = list
  description = "Comes from networking template"
}

variable "db_subnets" {
  type        = list
  description = "Comes from networking template"
}

data "aws_ssm_parameter" "amazon_linux_ami" {
  name = "/aws/service/canonical/ubuntu/server-minimal/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

locals {
  name_tag_prefix   = "${var.project_name}-${var.environment}"
}
