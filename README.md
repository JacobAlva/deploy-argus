# Argus Agent Terraform Deployment

Deploy the Argus DSPM agent in your AWS account with complete data sovereignty. Your sensitive data never leaves your environment.

[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.5-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20IAM%20%7C%20S3-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **New to Argus?** Start with the [5-minute Quick Start](QUICKSTART.md)

## What This Deploys

- **Argus Agent**: Secure container running in your AWS account
- **Data Sovereignty**: Your data never leaves your environment  
- **Minimal Permissions**: Read-only access to your S3 buckets
- **Enterprise Security**: Encrypted storage, audit logging, monitoring

## Quick Start

### Prerequisites

- AWS CLI v2.x configured with appropriate credentials
- Terraform >= 1.5.0
- Docker (for local testing)
- `jq`, `curl`, `openssl` utilities

### 1. Validate Your Environment

```bash
# Run pre-deployment validation
./scripts/validate-deployment.sh --region us-east-1 --verbose
```

### 2. Deploy Agent (Automated)

```bash
# Automated deployment for new customer
./scripts/customer-onboarding.sh --customer-name acme-corp --region us-east-1
```

### 3. Manual Deployment (Advanced)

```bash
# Create deployment directory
mkdir -p deployments/my-customer-us-east-1
cd deployments/my-customer-us-east-1

# Create main.tf using the module
cat > main.tf << 'EOF'
module "argus_agent_ec2" {
  source = "../../terraform/modules/argus-agent-ec2"
  
  customer_name     = "my-customer"
  agent_api_key     = "your-secure-api-key-here"
  argus_backend_url = "https://api.argus-dspm.com"
  
  aws_region    = "us-east-1"
  instance_type = "t3.medium"
  environment   = "prod"
}
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

## Module Structure

```
terraform/
├── modules/
│   └── argus-agent-ec2/           # EC2-based agent deployment
│       ├── main.tf                # Core infrastructure
│       ├── variables.tf           # Input parameters
│       ├── outputs.tf             # Return values
│       ├── security.tf            # IAM roles and security groups
│       ├── compute.tf             # EC2 instances and auto-scaling
│       ├── monitoring.tf          # CloudWatch monitoring
│       └── user_data.sh           # Instance bootstrap script
└── examples/
    ├── basic-deployment/          # Simple single-instance deployment
    ├── production-deployment/     # Full production setup
    └── multi-region-deployment/   # Multi-region agent deployment
```

## Module Configuration

### Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `customer_name` | Customer identifier | `string` | `"acme-corp"` |
| `agent_api_key` | Secure API key from Argus | `string` | `"abc123..."` |

### Optional Variables

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `aws_region` | AWS deployment region | `"us-east-1"` | Any AWS region |
| `instance_type` | EC2 instance type | `"t3.medium"` | `t3.small`, `t3.large`, `c5.large` |
| `environment` | Environment name | `"prod"` | `dev`, `staging`, `prod` |
| `enable_ssh_access` | Enable SSH debugging | `false` | `true`, `false` |
| `auto_scaling_enabled` | Enable auto-scaling | `false` | `true`, `false` |

### Complete Variable Reference

See [variables.tf](modules/argus-agent-ec2/variables.tf) for all available options.

## Security Features

### Data Sovereignty
- **No Data Transmission**: Customer data never leaves their AWS account
- **Metadata Only**: Only aggregated findings and metadata sent to backend
- **Local Processing**: All sensitive data analysis performed within customer VPC

### IAM Security
- **Least Privilege**: Minimal IAM permissions (S3 read-only, logs write)
- **Cross-Account Access**: Secure role assumption with external ID
- **No Long-Term Credentials**: Uses temporary STS credentials only

### Network Security
- **VPC Isolation**: Agent runs in customer VPC with security groups
- **HTTPS Only**: All external communication over HTTPS
- **No Inbound Access**: Agent initiates all connections (outbound only)

### Infrastructure Security
- **Encrypted Storage**: EBS volumes encrypted at rest
- **Instance Metadata**: IMDSv2 enforced for enhanced security
- **Container Security**: Non-root user in container, minimal base image

## Monitoring & Observability

### CloudWatch Integration
- **Application Logs**: Structured logging with configurable retention
- **System Metrics**: CPU, memory, disk, and network monitoring
- **Custom Metrics**: Agent-specific performance and job metrics
- **Automated Alerts**: SNS notifications for critical issues

### Built-in Dashboards
- Instance health and performance metrics
- Agent job execution statistics
- Error rates and troubleshooting logs
- Cost optimization recommendations

### Health Checks
- **Container Health**: Docker health checks with auto-restart
- **API Connectivity**: Backend communication monitoring
- **Resource Utilization**: Proactive resource monitoring

## Deployment Scenarios

### 1. Single Instance (MVP)
```hcl
module "argus_agent_ec2" {
  source = "./modules/argus-agent-ec2"
  
  customer_name = "customer-name"
  agent_api_key = var.agent_api_key
  instance_type = "t3.medium"
}
```

### 2. High Availability with Auto Scaling
```hcl
module "argus_agent_ec2" {
  source = "./modules/argus-agent-ec2"
  
  customer_name        = "customer-name"
  agent_api_key        = var.agent_api_key
  auto_scaling_enabled = true
  instance_type        = "t3.large"
  enable_detailed_monitoring = true
}
```

### 3. Development Environment
```hcl
module "argus_agent_ec2" {
  source = "./modules/argus-agent-ec2"
  
  customer_name     = "customer-dev"
  agent_api_key     = var.agent_api_key
  environment       = "dev"
  instance_type     = "t3.small"
  enable_ssh_access = true
}
```

## Troubleshooting

### Common Issues

#### 1. Permission Errors
```bash
# Validate AWS permissions
./scripts/validate-deployment.sh --region us-east-1

# Check specific IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ec2:RunInstances iam:CreateRole
```

#### 2. Instance Launch Failures
```bash
# Check EC2 service limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# Verify VPC and subnet configuration
terraform plan -target=module.argus_agent_ec2.aws_vpc.argus_vpc
```

#### 3. Agent Connectivity Issues
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id)

# Test backend connectivity
curl -v https://api.argus-dspm.com/health
```

#### 4. Container Issues
```bash
# Check instance logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name $(terraform output -raw agent_instance_id)/bootstrap
```

### Debugging Steps

1. **Validate Prerequisites**
   ```bash
   ./scripts/validate-deployment.sh --verbose
   ```

2. **Check Terraform State**
   ```bash
   terraform show
   terraform output
   ```

3. **Instance Debugging** (if SSH enabled)
   ```bash
   aws ssm start-session --target $(terraform output -raw agent_instance_id)
   # Or SSH if key pair configured
   ssh ec2-user@$(terraform output -raw agent_public_ip)
   ```

4. **Container Debugging**
   ```bash
   # On the instance
   docker logs argus-agent
   docker exec -it argus-agent /bin/bash
   ```

## 📈 Scaling Considerations

### Performance Optimization
- **Instance Types**: Use compute-optimized instances for heavy workloads
- **Auto Scaling**: Enable for variable workloads and high availability
- **Multiple Regions**: Deploy agents closer to data sources

### Cost Optimization
- **Instance Sizing**: Right-size based on actual usage patterns
- **Reserved Instances**: Use for predictable, long-term deployments
- **Spot Instances**: Consider for development/testing environments

### Monitoring Optimization
- **Log Retention**: Adjust based on compliance requirements
- **Metric Resolution**: Use detailed monitoring only when needed
- **Alert Thresholds**: Tune based on baseline performance

## Updates and Maintenance

### Agent Updates
```bash
# Update agent container image
cd deployments/customer-name-region
terraform apply -var="agent_container_image=argus-agent:v1.2.0"
```

### Infrastructure Updates
```bash
# Update Terraform module
git pull origin main
cd deployments/customer-name-region
terraform init -upgrade
terraform plan
terraform apply
```

### Backup and Recovery
- **Terraform State**: Store in S3 backend with versioning
- **Configuration Backup**: Version control all configuration
- **Disaster Recovery**: Document recovery procedures

## Support

### Getting Help
- **Documentation**: Check [agent_based_architecture.md](../docs/agent_based_architecture.md)
- **Validation**: Run `./scripts/validate-deployment.sh`
- **Logs**: Check CloudWatch logs for detailed error information

### Reporting Issues
When reporting issues, please include:
1. Terraform version (`terraform version`)
2. AWS CLI version (`aws --version`)
3. Deployment region and configuration
4. Relevant error messages and logs
5. Validation script output

### Emergency Procedures
1. **Agent Failure**: Auto-scaling will replace failed instances
2. **Complete Outage**: Re-run deployment script to restore
3. **Security Incident**: Immediate instance termination via console