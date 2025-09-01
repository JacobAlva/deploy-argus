# Argus Agent EC2 Deployment Module - Main Configuration
# This module creates a secure, production-ready Argus agent deployment on EC2

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Data sources for AWS information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Get the most recent Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local values for resource naming and configuration
locals {
  # Generate unique identifiers
  agent_id = "${var.customer_name}-agent-${random_id.agent_suffix.hex}"
  
  # External ID for cross-account role assumption
  external_id = var.external_id != "" ? var.external_id : random_password.external_id.result
  
  # Network configuration
  vpc_id    = var.vpc_id != "" ? var.vpc_id : aws_vpc.argus_vpc[0].id
  subnet_id = var.subnet_id != "" ? var.subnet_id : aws_subnet.argus_subnet[0].id
  
  # Availability zone selection
  selected_az = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
  
  # Common tags for all resources
  common_tags = merge({
    Name        = "argus-agent-${var.customer_name}"
    Customer    = var.customer_name
    Environment = var.environment
    Component   = "argus-agent"
    ManagedBy   = "terraform"
    Project     = "argus-dspm"
    AgentId     = local.agent_id
  }, var.additional_tags)
  
  # User data script for EC2 instance
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    agent_api_key_secret_name = aws_secretsmanager_secret.agent_api_key.name
    argus_backend_url         = var.argus_backend_url
    agent_container_image     = var.agent_container_image
    agent_log_level          = var.agent_log_level
    health_check_interval    = var.health_check_interval
    cloudwatch_log_group     = aws_cloudwatch_log_group.argus_agent_logs.name
    aws_region               = var.aws_region
    agent_id                 = local.agent_id
  }))
}

# Generate random suffix for unique naming
resource "random_id" "agent_suffix" {
  byte_length = 4
}

# Generate external ID for cross-account role assumption
resource "random_password" "external_id" {
  length  = 32
  special = false
  upper = true
  lower = true
  numeric = true
}

# Create VPC if not provided
resource "aws_vpc" "argus_vpc" {
  count = var.vpc_id == "" ? 1 : 0
  
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "argus-vpc-${var.customer_name}"
  })
}

# Create Internet Gateway for VPC
resource "aws_internet_gateway" "argus_igw" {
  count = var.vpc_id == "" ? 1 : 0
  
  vpc_id = aws_vpc.argus_vpc[0].id
  
  tags = merge(local.common_tags, {
    Name = "argus-igw-${var.customer_name}"
  })
}

# Create subnet if not provided
resource "aws_subnet" "argus_subnet" {
  count = var.subnet_id == "" ? 1 : 0
  
  vpc_id                  = local.vpc_id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.selected_az
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "argus-subnet-${var.customer_name}"
  })
}

# Create route table for public subnet
resource "aws_route_table" "argus_rt" {
  count = var.vpc_id == "" ? 1 : 0
  
  vpc_id = aws_vpc.argus_vpc[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.argus_igw[0].id
  }
  
  tags = merge(local.common_tags, {
    Name = "argus-rt-${var.customer_name}"
  })
}

# Associate route table with subnet
resource "aws_route_table_association" "argus_rta" {
  count = var.subnet_id == "" ? 1 : 0
  
  subnet_id      = aws_subnet.argus_subnet[0].id
  route_table_id = aws_route_table.argus_rt[0].id
}

# CloudWatch Log Group for agent logs
resource "aws_cloudwatch_log_group" "argus_agent_logs" {
  name              = "/argus/agent/${local.agent_id}"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-logs-${var.customer_name}"
  })
}

# Secrets Manager secret for API key
resource "aws_secretsmanager_secret" "agent_api_key" {
  name                    = "argus/agent/${local.agent_id}/api-key"
  description            = "Argus agent API key for ${var.customer_name}"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-api-key-${var.customer_name}"
  })
}

# Store the API key in Secrets Manager
resource "aws_secretsmanager_secret_version" "agent_api_key" {
  secret_id     = aws_secretsmanager_secret.agent_api_key.id
  secret_string = var.agent_api_key
}