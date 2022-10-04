/*
This template is for provisioning of
  any resource that uses instances such as
  EC2 and RDS
*/

# No inbound rules because this is meant to be access via
# session manager
resource "aws_security_group" "bastion" {
  name        = "${local.name_tag_prefix}-Bastion-Sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow to anywhere from this bastion"
  }

  tags = {
    Name    = "${local.name_tag_prefix}-Bastion-Sg"
    Env     = var.environment
    Project = var.project_name
  }
}

resource "aws_security_group" "dms" {
  name        = "${local.name_tag_prefix}-RepInstance-Sg"
  description = "Security group for replication instance"
  vpc_id      = var.vpc
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow to anywhere from this replication instance."
  }

  tags = {
    Name    = "${local.name_tag_prefix}-RepInstance-Sg"
    Env     = var.environment
    Project = var.project_name
  }
}


resource "aws_iam_role" "ssm_role" {
  name_prefix = "${var.project_name}${var.environment}"
  path        = "/${var.project_name}/${var.environment}/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
}
EOF

  tags = {
    Env     = var.environment
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.ssm_role.id
}

resource "aws_iam_role_policy" "ssm_policy" {
  name_prefix = "${var.project_name}${var.environment}"
  role        = aws_iam_role.ssm_role.id
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:UpdateInstanceInformation",
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetEncryptionConfiguration"
            ],
            "Resource": "*"
        }
    ]
}
  EOF
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name_prefix = "${var.project_name}${var.environment}"
  path        = "/${var.project_name}/${var.environment}/"
  role        = aws_iam_role.ssm_role.name
}

resource "aws_instance" "bastion" {
  ami                  = data.aws_ssm_parameter.amazon_linux_ami.value
  subnet_id            = var.private_subnets[0]
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name
  security_groups      = [aws_security_group.bastion.id]
  user_data            = <<-EOF
    #!/bin/bash
    curl --max-time 20 --retry 5 http://repo.mysql.com/yum/mysql-5.5-community/el/7/x86_64/mysql-community-release-el7-5.noarch.rpm
    apt update -y
    apt upgrade -y
    apt install git vim -y
    cd /usr/local
    git clone https://github.com/CISOfy/lynis
    EOF
  tags = {
    Name    = "${local.name_tag_prefix}-BastionInstance"
    Env     = var.environment
    Project = var.project_name
  }
} 