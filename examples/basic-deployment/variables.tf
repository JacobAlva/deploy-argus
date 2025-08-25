# Variables for Argus Agent Basic Deployment Example

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

# AWS Configuration
variable "aws_region" {
  description = "AWS region for agent deployment"
  type        = string
  default     = "us-east-2"
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

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for the agent"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition = contains([
      "t3.small", "t3.medium", "t3.large", "t3.xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a supported type."
  }
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

# Security Configuration
variable "enable_ssh_access" {
  description = "Enable SSH access for debugging (not recommended for production)"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (required if enable_ssh_access is true)"
  type        = list(string)
  default     = []
  
  validation {
    condition = length(var.allowed_cidr_blocks) == 0 || alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid."
  }
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access (optional, for debugging only)"
  type        = string
  default     = ""
}