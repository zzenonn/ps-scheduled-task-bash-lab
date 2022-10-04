provider "aws" {
  region  = "us-west-2"
  profile = "terraform"
}

module "network" {
    source          = "./modules/infrastructure/network"
    project_name    = var.project_name
    environment     = var.environment
    db_port         = var.db_port
    networks        = var.networks
}

module "instances" {
    source  = "./modules/infrastructure/instances"
    project_name    = module.network.project_name
    environment     = module.network.environment
    vpc             = module.network.vpc
    private_subnets = module.network.private_subnets
    public_subnets  = module.network.public_subnets
    db_subnets      = module.network.db_subnets
}

resource "aws_s3_bucket" "output" {
}

resource "aws_s3_bucket_policy" "public_access" {
  bucket = aws_s3_bucket.output.id
  policy = data.aws_iam_policy_document.public_access.json
}

data "aws_iam_policy_document" "public_access" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.output.arn,
      "${aws_s3_bucket.output.arn}/*",
    ]
  }
}