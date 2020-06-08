/*
This template is for provisioning of a cicd pipeline with an ecs blue green 
deployment
*/

resource "aws_s3_bucket" "artifact_store" {
  bucket_prefix = lower(local.name_tag_prefix)
  acl    = "private"
}

resource "aws_iam_role" "codepipeline" {
  name_prefix = local.name_tag_prefix
  path        = "/${var.project_name}/${var.environment}/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "codepipeline.amazonaws.com"
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
    Service = var.service
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name_prefix = local.name_tag_prefix
  role        = aws_iam_role.codepipeline.id
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "serverlessrepo:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
          "Effect":"Allow",
          "Action": [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "s3:PutObject"
          ],
          "Resource": [
            "${aws_s3_bucket.artifact_store.arn}",
            "${aws_s3_bucket.artifact_store.arn}/*"
          ]
        },
        {
            "Action": [
              "ecr:BatchCheckLayerAvailability",
              "ecr:CompleteLayerUpload",
              "ecr:GetAuthorizationToken",
              "ecr:InitiateLayerUpload",
              "ecr:PutImage",
              "ecr:UploadLayerPart"
            ],
            "Resource": "*",
            "Effect": "Allow"
      }
    ]
}
EOF
}


resource "aws_iam_role" "codebuild" {
  name_prefix = local.name_tag_prefix
  path        = "/${var.project_name}/${var.environment}/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "codebuild.amazonaws.com"
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
    Service = var.service
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name_prefix = local.name_tag_prefix
  role        = aws_iam_role.codebuild.id
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "serverlessrepo:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
          "Effect":"Allow",
          "Action": [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "s3:PutObject"
          ],
          "Resource": [
            "${aws_s3_bucket.artifact_store.arn}",
            "${aws_s3_bucket.artifact_store.arn}/*"
          ]
        },     
        {
          "Effect":"Allow",
          "Action": [
            "codebuild:StartBuild",
            "codebuild:BatchGetBuilds"
          ],
          "Resource": [
            "${aws_codebuild_project.service.arn}"
          ]
        },
        {
            "Action": [
              "ecr:BatchCheckLayerAvailability",
              "ecr:CompleteLayerUpload",
              "ecr:GetAuthorizationToken",
              "ecr:InitiateLayerUpload",
              "ecr:PutImage",
              "ecr:UploadLayerPart"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_codebuild_project" "service" {
  name          = local.name_tag_prefix
  description   = "Build for ${var.service} service"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PROJECTNAME"
      value = lower(var.project_name)
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = lower(var.environment)
    }
    
    environment_variable {
      name  = "SERVICE"
      value = lower(var.service)
    }
  }

  source {
    type        = "CODEPIPELINE"
  }
  tags = {
    Env     = var.environment
    Project = var.project_name
    Service = var.service
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${local.name_tag_prefix}-Pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.git_owner
        Repo       = var.git_repo
        Branch     = lower(var.environment)
        OAuthToken = data.aws_ssm_parameter.github_token.value
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.service.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName                = var.codedeploy_app
        DeploymentGroupName            = var.codedeploy_deployment_group
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = "build_output"
        Image1ContainerName            = " IMAGE1_NAME"
        
      }
    }
  }
}