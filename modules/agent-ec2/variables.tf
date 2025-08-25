# Argus Agent EC2 Deployment Module - Variables
# This module deploys an Argus agent on EC2 for secure customer data scanning

# Required Variables
variable "customer_name" {
  description = "Customer name for resource naming and tagging"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.customer_name))
    error_message = "Customer name must contain only alphanumeric characters and hyphens."
  }
}

variable "agent_api_key" {
  description = "Argus agent API key for backend authentication"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.agent_api_key) >= 32
    error_message = "Agent API key must be at least 32 characters long."
  }
}

variable "argus_backend_url" {
  description = "Argus SaaS backend URL for agent communication"
  type        = string
  default     = "https://api.argus-dspm.com"
  validation {
    condition     = can(regex("^https://", var.argus_backend_url))
    error_message = "Backend URL must use HTTPS."
  }
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for agent deployment"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone for EC2 instance (optional, will use first AZ if not specified)"
  type        = string
  default     = ""
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID for agent deployment (optional, will create new VPC if not specified)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for agent deployment (optional, will create new subnet if not specified)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (optional, for debugging only)"
  type        = list(string)
  default     = []
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type for the agent"
  type        = string
  default     = "t3.medium"
  validation {
    condition     = contains(["t3.small", "t3.medium", "t3.large", "t3.xlarge", "c5.large", "c5.xlarge"], var.instance_type)
    error_message = "Instance type must be one of: t3.small, t3.medium, t3.large, t3.xlarge, c5.large, c5.xlarge."
  }
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access (optional, for debugging only)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.root_volume_size >= 20 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 20 and 100 GB."
  }
}

# Agent Configuration
variable "agent_container_image" {
  description = "Docker container image for Argus agent"
  type        = string
  default     = "argus-agent:latest"
}

variable "agent_log_level" {
  description = "Agent logging level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.agent_log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.health_check_interval >= 10 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 10 and 300 seconds."
  }
}

# Security Configuration
variable "enable_ssh_access" {
  description = "Enable SSH access for debugging (not recommended for production)"
  type        = bool
  default     = false
}

variable "external_id" {
  description = "External ID for cross-account role assumption (will be generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# Monitoring Configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Advanced Configuration
variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for high availability (creates Auto Scaling Group)"
  type        = bool
  default     = false
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}