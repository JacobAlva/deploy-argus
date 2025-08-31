# Argus Agent Basic Deployment Example
# This example shows a simple, single-instance deployment

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Deploy Argus Agent using the EC2 module
module "argus_agent_ec2" {
  source = "../../modules/argus-agent-ec2"
  
  # Required variables
  customer_name     = var.customer_name
  agent_api_key     = var.agent_api_key
  argus_backend_url = var.argus_backend_url
  argus_provider_account_id = var.argus_provider_account_id
  
  # AWS Configuration
  aws_region = var.aws_region
  
  # Basic instance configuration
  instance_type = var.instance_type
  environment   = var.environment
  
  # Security configuration
  enable_ssh_access     = var.enable_ssh_access
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  key_pair_name         = var.key_pair_name
  
  # Monitoring configuration
  enable_detailed_monitoring = true
  log_retention_days        = 30
  
  # Additional tags
  additional_tags = {
    Project     = "argus-dspm"
    DeployedBy  = "terraform-example"
    Environment = var.environment
  }
}

# Outputs from the deployment
output "agent_instance_id" {
  description = "EC2 instance ID of the deployed agent"
  value       = module.argus_agent_ec2.agent_instance_id
}

output "agent_role_arn" {
  description = "ARN of the IAM role assigned to the agent"
  value       = module.argus_agent_ec2.agent_role_arn
}

output "agent_private_ip" {
  description = "Private IP address of the agent instance"
  value       = module.argus_agent_ec2.agent_private_ip
}

output "security_group_id" {
  description = "Security group ID for the agent"
  value       = module.argus_agent_ec2.security_group_id
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for agent logs"
  value       = module.argus_agent_ec2.cloudwatch_log_group_name
}

output "external_id" {
  description = "External ID for cross-account role assumption"
  value       = module.argus_agent_ec2.external_id
  sensitive   = true
}

output "deployment_info" {
  description = "Complete deployment information"
  value = {
    customer_name    = var.customer_name
    region          = var.aws_region
    environment     = var.environment
    instance_id     = module.argus_agent_ec2.agent_instance_id
    role_arn        = module.argus_agent_ec2.agent_role_arn
    deployment_time = module.argus_agent_ec2.deployment_timestamp
  }
}