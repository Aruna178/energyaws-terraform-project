# Create an ECR Repository
resource "aws_ecr_repository" "app" {
  name = var.repository_name
}

# Create a CodeCommit Repository
resource "aws_codecommit_repository" "app" {
  repository_name = var.app_name

  default_branch = "main"

  description = "CodeCommit repository for ${var.app_name}"

  repository_name = var.app_name

  tags = {
    Environment = "Production"
  }
}

# Create an IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.app_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Policies to CodeBuild Role
resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Create a CodeBuild Project
resource "aws_codebuild_project" "app" {
  name          = "${var.app_name}-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "20"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.app.clone_url_http
    buildspec = var.buildspec
  }
}

# Create an IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.app_name}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Policies to CodeDeploy Role
resource "aws_iam_role_policy_attachment" "codedeploy_access" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Create a CodeDeploy Application
resource "aws_codedeploy_app" "app" {
  name             = var.app_name
  compute_platform = "ECS"
}

# Create a CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "app" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.app_name}-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = var.cluster_name
    service_name = var.service_name
  }
}

# Create a CodePipeline
resource "aws_codepipeline" "app" {
  name     = "${var.app_name}-pipeline"
  role_arn = aws_iam_role.codedeploy_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_bucket.id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.app.repository_name
        BranchName     = "main"
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
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app.deployment_group_name
      }
    }
  }
}

# Create an S3 Bucket for Pipeline Artifacts
resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = "${var.app_name}-pipeline-artifacts"
}

output "codepipeline_id" {
  value = aws_codepipeline.app.id
}

output "codebuild_project_name" {
  value = aws_codebuild_project.app.name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.app.name
}

output "codecommit_clone_url" {
  value = aws_codecommit_repository.app.clone_url_http
}

