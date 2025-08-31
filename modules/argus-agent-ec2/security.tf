# Argus Agent EC2 Deployment Module - Security Configuration
# This file contains IAM roles, policies, and security groups for the agent

# Security Group for Argus Agent
resource "aws_security_group" "argus_agent_sg" {
  name        = "argus-agent-sg-${var.customer_name}"
  description = "Security group for Argus agent - minimal access for data sovereignty"
  vpc_id      = local.vpc_id
  
  # Outbound HTTPS for backend communication
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for Argus backend communication"
  }
  
  # Outbound HTTP for package updates and container pulls
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound for system updates"
  }
  
  # Outbound DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }
  
  # Health check endpoint (internal only)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : aws_vpc.argus_vpc[0].cidr_block]
    description = "Health check endpoint - internal VPC only"
  }
  
  # Conditional SSH access for debugging (not recommended for production)
  dynamic "ingress" {
    for_each = var.enable_ssh_access && length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "SSH access for debugging - remove in production"
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-sg-${var.customer_name}"
  })
}

# Data source for existing VPC (if provided)
data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

# IAM Role for Argus Agent
resource "aws_iam_role" "argus_agent_role" {
  name = "ArgusAgentRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow EC2 instances to assume this role
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      # Allow cross-account access from Argus backend
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.argus_provider_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-role-${var.customer_name}"
  })
}

# IAM Policy for S3 Access (based on existing aws-iam-policy.json)
resource "aws_iam_policy" "argus_agent_s3_policy" {
  name        = "ArgusAgentS3Policy-${var.customer_name}"
  description = "S3 access policy for Argus agent - read-only with minimal privileges"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid    = "S3ObjectReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::*/*"
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-s3-policy-${var.customer_name}"
  })
}

# IAM Policy for Secrets Manager Access
resource "aws_iam_policy" "argus_agent_secrets_policy" {
  name        = "ArgusAgentSecretsPolicy-${var.customer_name}"
  description = "Secrets Manager access for Argus agent API key retrieval"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.agent_api_key.arn
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-secrets-policy-${var.customer_name}"
  })
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_policy" "argus_agent_logs_policy" {
  name        = "ArgusAgentLogsPolicy-${var.customer_name}"
  description = "CloudWatch Logs access for Argus agent logging"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.argus_agent_logs.arn,
          "${aws_cloudwatch_log_group.argus_agent_logs.arn}:*"
        ]
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-logs-policy-${var.customer_name}"
  })
}

# IAM Policy for EC2 metadata and basic operations
resource "aws_iam_policy" "argus_agent_ec2_policy" {
  name        = "ArgusAgentEC2Policy-${var.customer_name}"
  description = "EC2 metadata and basic operations for Argus agent"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2MetadataAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-ec2-policy-${var.customer_name}"
  })
}

# Attach policies to the IAM role
resource "aws_iam_role_policy_attachment" "argus_agent_s3_attachment" {
  policy_arn = aws_iam_policy.argus_agent_s3_policy.arn
  role       = aws_iam_role.argus_agent_role.name
}

resource "aws_iam_role_policy_attachment" "argus_agent_secrets_attachment" {
  policy_arn = aws_iam_policy.argus_agent_secrets_policy.arn
  role       = aws_iam_role.argus_agent_role.name
}

resource "aws_iam_role_policy_attachment" "argus_agent_logs_attachment" {
  policy_arn = aws_iam_policy.argus_agent_logs_policy.arn
  role       = aws_iam_role.argus_agent_role.name
}

resource "aws_iam_role_policy_attachment" "argus_agent_ec2_attachment" {
  policy_arn = aws_iam_policy.argus_agent_ec2_policy.arn
  role       = aws_iam_role.argus_agent_role.name
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "argus_agent_profile" {
  name = "argus-agent-profile-${var.customer_name}"
  role = aws_iam_role.argus_agent_role.name
  
  tags = merge(local.common_tags, {
    Name = "argus-agent-profile-${var.customer_name}"
  })
}