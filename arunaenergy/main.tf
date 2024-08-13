provider "aws" {
  region = "us-west-2"  # Change to your preferred region
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  vpc_cidr_block             = "10.0.0.0/16"
  public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Security Module
module "security" {
  source = "./modules/security"

  vpc_id = module.networking.vpc_id
}

# DNS Module
module "dns" {
  source         = "./modules/dns"
  domain         = "example.com"  # Replace with your domain
  public_ip      = module.networking.public_ip
  hosted_zone_id = "<YOUR_HOSTED_ZONE_ID>"  # Replace with your hosted zone ID
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_id  = module.security.web_security_group_id
  cluster_name       = "my-ecs-cluster"
  app_name           = "my-app"
  container_port     = 80
  image              = "nginx"  # Replace with your container image
  target_group_arn   = module.networking.ecs_target_group_arn
}

# CI/CD Module
module "cicd" {
  source           = "./modules/cicd"

  app_name         = module.ecs.app_name
  cluster_name     = module.ecs.cluster_name
  service_name     = module.ecs.ecs_service_name
  image            = module.ecs.image
  repository_name  = "my-repo"  # Replace with your ECR repository name
  buildspec        = file("${path.module}/buildspec.yml")  # Add your buildspec.yml
}

# Observability Module
module "observability" {
  source          = "./modules/observability"

  cluster_name    = module.ecs.cluster_name
  service_name    = module.ecs.ecs_service_name
  ecs_cluster_arn = module.ecs.ecs_cluster_id
  sns_topic_name  = "my-alerts"  # Name for the SNS topic
  alert_email     = "alerts@example.com"  # Email to receive alerts
}

# Application Logging Module
module "application_logging" {
  source          = "./modules/application_logging"

  app_name        = module.ecs.app_name
  log_group_name  = "/aws/ecs/${module.ecs.cluster_name}/${module.ecs.app_name}-app"
  sns_topic_arn   = module.observability.sns_topic_arn
  metric_name     = "ErrorCount"
  namespace       = "MyApp/CustomMetrics"
}

# Output the load balancer DNS name
output "load_balancer_dns" {
  value = module.networking.load_balancer_dns
}

