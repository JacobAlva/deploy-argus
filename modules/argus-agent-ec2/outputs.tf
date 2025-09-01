# Argus Agent EC2 Deployment Module - Outputs
# These outputs provide essential information about the deployed agent infrastructure

# Agent Instance Information
output "agent_instance_id" {
  description = "EC2 instance ID of the deployed agent"
  value       = aws_instance.argus_agent.id
}

output "agent_instance_arn" {
  description = "ARN of the agent EC2 instance"
  value       = aws_instance.argus_agent.arn
}

output "agent_private_ip" {
  description = "Private IP address of the agent instance"
  value       = aws_instance.argus_agent.private_ip
}

output "agent_public_ip" {
  description = "Public IP address of the agent instance (if assigned)"
  value       = aws_instance.argus_agent.public_ip
}

output "agent_availability_zone" {
  description = "Availability zone where the agent is deployed"
  value       = aws_instance.argus_agent.availability_zone
}

# IAM Information
output "agent_role_arn" {
  description = "ARN of the IAM role assigned to the agent"
  value       = aws_iam_role.argus_agent_role.arn
}

output "agent_role_name" {
  description = "Name of the IAM role assigned to the agent"
  value       = aws_iam_role.argus_agent_role.name
}

output "agent_instance_profile_arn" {
  description = "ARN of the instance profile for the agent"
  value       = aws_iam_instance_profile.argus_agent_profile.arn
}

output "external_id" {
  description = "External ID for cross-account role assumption"
  value       = local.external_id
  sensitive   = true
}

# Network Information
output "vpc_id" {
  description = "VPC ID where the agent is deployed"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "Subnet ID where the agent is deployed"
  value       = local.subnet_id
}

output "security_group_id" {
  description = "Security group ID for the agent"
  value       = aws_security_group.argus_agent_sg.id
}

# Secrets Management
output "api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the agent API key"
  value       = aws_secretsmanager_secret.agent_api_key.arn
}

output "api_key_secret_name" {
  description = "Name of the Secrets Manager secret containing the agent API key"
  value       = aws_secretsmanager_secret.agent_api_key.name
}

# Monitoring Information
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for agent logs"
  value       = aws_cloudwatch_log_group.argus_agent_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for agent logs"
  value       = aws_cloudwatch_log_group.argus_agent_logs.arn
}

# Agent Configuration
output "agent_endpoint_url" {
  description = "Health check endpoint URL for the agent"
  value       = "http://${aws_instance.argus_agent.private_ip}:8000/health"
}

# Deployment Information
output "deployment_timestamp" {
  description = "Timestamp of the deployment"
  value       = timestamp()
}

output "customer_name" {
  description = "Customer name for this deployment"
  value       = var.customer_name
}

output "environment" {
  description = "Environment name for this deployment"
  value       = var.environment
}

# Resource Tags
output "resource_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# Connection Information for Backend Integration
output "agent_connection_info" {
  description = "Information needed for backend agent registration"
  value = {
    agent_id             = local.agent_id
    instance_id          = aws_instance.argus_agent.id
    role_arn            = aws_iam_role.argus_agent_role.arn
    external_id         = local.external_id
    region              = var.aws_region
    availability_zone   = aws_instance.argus_agent.availability_zone
    private_ip          = aws_instance.argus_agent.private_ip
    deployment_time     = timestamp()
    customer_name       = var.customer_name
    environment         = var.environment
  }
  sensitive = true
}