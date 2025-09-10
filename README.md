# Argus DSPM Agent - Terraform Deployment

Deploy the Argus DSPM agent in your AWS account with complete data sovereignty. Your sensitive data never leaves your environment.

[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.5-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20IAM%20%7C%20S3-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What This Deploys

**Production-Ready Agent Infrastructure:**
- **Secure EC2 Agent**: Containerized agent running in your AWS account
- **Zero Data Exfiltration**: Only metadata and findings summaries leave your environment  
- **Same-Account Operation**: No cross-account role assumption needed
- **Container Security**: ECR-hosted images with automatic updates
- **Enterprise Monitoring**: CloudWatch logs, metrics, and alerting

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Customer AWS Account                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                      VPC                                    ││
│  │  ┌─────────────────┐    ┌─────────────────┐                 ││
│  │  │   EC2 Instance  │    │  CloudWatch     │                 ││
│  │  │  ┌───────────┐  │    │  Logs & Metrics │                 ││
│  │  │  │  Argus    │  │    └─────────────────┘                 ││
│  │  │  │  Agent    │◄─┼─────────────────────────────────┐      ││
│  │  │  │Container  │  │                                 │      ││
│  │  │  └───────────┘  │    ┌─────────────────┐          │      ││
│  │  │                 │    │ Secrets Manager │          │      ││
│  │  │ ArgusAgentRole  │    │   (API Keys)    │          │      ││
│  │  └─────────────────┘    └─────────────────┘          │      ││
│  │           │                                          │      ││
│  │           ▼                                          │      ││
│  │  ┌─────────────────┐                                 │      ││
│  │  │   S3 Buckets    │◄────────────────────────────────┘      ││
│  │  │   (Read Only)   │                                        ││
│  │  └─────────────────┘                                        ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                │
                          HTTPS │ (Metadata Only)
                                ▼
                    ┌─────────────────────────────┐
                    │     Argus SaaS Backend      │
                    └─────────────────────────────┘
```

## Prerequisites

- **AWS CLI** v2.x configured with appropriate credentials
- **Terraform** >= 1.5.0
- **Docker** running (for building/testing)
- **ECR Repository** with Argus agent image
- **Agent API Key** from Argus backend

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/JacobAlva/deploy-argus.git
cd deploy-argus/examples/basic-deployment

# Copy and configure terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update Configuration

Edit `terraform.tfvars`:

```hcl
# Required
customer_name = "acme-corp"
agent_api_key = "argus_sk_xxx_your-secure-api-key-here"

# ECR Configuration (Update with your ECR URI)
agent_container_image = "AWS_ACCOUNT.dkr.ecr.AWS_REGION.amazonaws.com/argus-agent:latest"

# Backend URL
argus_backend_url = "https://your-backend-url"

# Argus Provider Account (for ECR access)
argus_provider_account_id = "AWS_ACCOUNT"

# Optional
aws_region    = "us-east-2"
instance_type = "t3.medium"
environment   = "prod"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Check instance status
terraform output

# Verify agent connectivity
aws logs describe-log-groups --log-group-name-prefix "/argus/agent"

# Check agent container
aws ssm start-session --target $(terraform output -raw agent_instance_id)
# Then: docker logs argus-agent
```

## Module Structure

```
deploy-argus/
├── modules/
│   └── argus-agent-ec2/           # Production-ready EC2 module
│       ├── main.tf                # Core infrastructure & networking
│       ├── variables.tf           # All configuration options
│       ├── outputs.tf             # Deployment information
│       ├── security.tf            # IAM roles & security groups
│       ├── compute.tf             # EC2 instances & auto-scaling
│       └── user_data.sh           # Agent bootstrap script
└── examples/
    └── basic-deployment/          # Simple deployment example
        ├── main.tf
        ├── terraform.tfvars.example
        └── README.md
```

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `customer_name` | Unique customer identifier | `"acme-corp"` |
| `agent_api_key` | Agent authentication key | `"argus_sk_xxx..."` |
| `argus_provider_account_id` | Argus AWS account ID for ECR access | `"123456789"` |

### Key Optional Variables

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `argus_backend_url` | Backend API URL | `"https://api.argus-dspm.com"` | Your backend URL |
| `agent_container_image` | ECR image URI | `"YOUR_ECR_URI_HERE"` | Full ECR image path |
| `aws_region` | Deployment region | `"us-east-1"` | Any AWS region |
| `instance_type` | EC2 instance size | `"t3.medium"` | `t3.small` to `c5.xlarge` |
| `enable_ssh_access` | SSH debugging access | `false` | `true/false` |
| `environment` | Environment tag | `"prod"` | `dev/staging/prod` |

## Security Implementation

### Data Sovereignty
- **Same-Account Operation**: No cross-account role assumption
- **Instance Credentials**: Uses EC2 instance role for S3 access
- **Local Processing**: All sensitive data analysis stays in customer VPC
- **Metadata Only**: Only aggregated findings sent to backend


### Security Implementation

```
Customer AWS Account
├── EC2 Instance (Agent)
│   ├── ArgusAgentRole (Instance Role)
│   │   ├── S3 Read Access
│   │   ├── ECR Pull Access  
│   │   ├── Secrets Manager Read
│   │   ├── CloudWatch Logs Write
│   │   └── EC2 Metadata Access
│   └── Docker Container (argus-agent:latest)
│       ├── Same-account credential detection
│       ├── Instance credential usage
│       └── S3 scanning with local processing
├── Secrets Manager (API Key Storage)
├── CloudWatch Logs (Agent Monitoring)
└── S3 Buckets (Scanned Resources)
```

### Network Security
- **VPC Isolation**: Private subnets with controlled egress
- **Security Groups**: HTTPS/SSH only (SSH optional)
- **EC2 Instance Connect**: Secure SSH access when enabled
- **No Inbound**: Agent initiates all connections

### Container Security
- **ECR Images**: Signed container images from private registry
- **Auto-restart**: Container health checks with automatic recovery
- **Resource Limits**: CPU/memory constraints for stability
- **Log Management**: Structured logging with retention policies

## Outputs

After deployment, you'll get these important outputs:

| Output | Description | Usage |
|--------|-------------|-------|
| `agent_instance_id` | EC2 instance ID | SSH access and monitoring |
| `agent_role_arn` | IAM role ARN | Backend account linking |
| `external_id` | Security external ID | Backend authentication |
| `agent_id` | Unique agent identifier | Backend registration |
| `cloudwatch_log_group_name` | Log group name | Log monitoring and debugging |

## Post-Deployment Verification

### 1. Check Agent Health

```bash
# Verify instance is running
INSTANCE_ID=$(terraform output -raw agent_instance_id)
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID

# Check container status via SSH
aws ssm start-session --target $INSTANCE_ID
# On instance: docker ps && docker logs argus-agent
```

### 2. Verify Backend Connectivity

```bash
# Check agent logs for successful backend communication
LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name application \
  --start-from-head
```

### 3. Test S3 Access

The agent should automatically detect it's running in the same account as the target S3 buckets and use instance credentials directly (no role assumption).

### 4. Register with Backend

Use the outputs to register the agent in your Argus backend:
- Agent ID: `terraform output -raw agent_id`
- Role ARN: `terraform output -raw agent_role_arn`  
- External ID: `terraform output -raw external_id`


## Monitoring & Observability

### CloudWatch Integration
```bash
# Log Groups Created:
/argus/agent/{agent-id}/bootstrap    # Instance startup logs
/argus/agent/{agent-id}/application  # Agent application logs  
/argus/agent/{agent-id}/error        # Error and exception logs
```

### Key Metrics
- **Agent Health**: Container status and restarts
- **Job Processing**: Scan completion rates and timing
- **Resource Usage**: CPU, memory, disk utilization
- **API Connectivity**: Backend communication health

### Real-time Monitoring

```bash
# Monitor agent logs in real-time
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Check container health
aws ssm start-session --target $(terraform output -raw agent_instance_id)
# Then: docker logs -f argus-agent
```

### Log Analysis Queries

Use CloudWatch Insights:

```sql
# Find errors in the last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50

# Monitor job processing
fields @timestamp, @message
| filter @message like /Processing job/
| sort @timestamp desc
```

### Health Monitoring
```bash
# Check agent status
curl http://localhost:8080/health  # From instance

# View real-time logs
aws logs tail /argus/agent/your-agent-id/application --follow

# Monitor job processing
docker logs -f argus-agent
```

## Operational Procedures

### Agent Updates
```bash
# Update container image
cd terraform/examples/basic-deployment
terraform apply -var="agent_container_image=new-ecr-uri:latest"
```

### Scaling and Performance
- **Single Instance**: Suitable for most workloads
- **Auto-scaling**: Available for high-availability setups
- **Instance Sizing**: Adjust based on data volume

### Backup and Recovery
- **Infrastructure as Code**: Complete deployment reproducible
- **State Management**: Terraform state in S3 backend (recommended)
- **Configuration**: All settings version controlled

## Troubleshooting

### Common Issues

#### 1. ECR Access Denied
```bash
# Check ECR repository policy allows customer account
aws ecr describe-repository --repository-name argus-agent
aws ecr get-repository-policy --repository-name argus-agent
```

#### 2. Agent Container Not Starting
```bash
# Check bootstrap logs
aws logs get-log-events \
  --log-group-name "/argus/agent/your-agent-id" \
  --log-stream-name "bootstrap"

# SSH to instance (if enabled)
aws ssm start-session --target i-1234567890abcdef
docker logs argus-agent
```

#### 3. Backend Connectivity Issues
```bash
# Test backend connectivity from instance
aws ssm start-session --target $(terraform output -raw agent_instance_id)

# If on instance
curl -v https://your-backend-url/health

# Check security group rules
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)
```

#### 4. Permission Errors
```bash
# Verify IAM role permissions
aws iam get-role --role-name ArgusAgentRole
aws iam list-attached-role-policies --role-name ArgusAgentRole

# Test S3 access from instance
aws ssm start-session --target $(terraform output -raw agent_instance_id)
# On instance: aws s3 ls
```

### Debugging Workflow

1. **Check Terraform Outputs**
   ```bash
   terraform output
   terraform show
   ```

2. **Verify Instance Status**
   ```bash
   aws ec2 describe-instances --instance-ids $(terraform output -raw agent_instance_id)
   ```

3. **Check Container Health**
   ```bash
   # SSH to instance
   aws ssm start-session --target $(terraform output -raw agent_instance_id)
   
   # Check container
   docker ps -a
   docker logs argus-agent
   ```

4. **Monitor Logs**
   ```bash
   aws logs tail /argus/agent/$(terraform output -raw agent_id)/application --follow
   ```

## Updates and Maintenance

### Agent Container Updates

```bash
# Update to new container version
terraform apply -var="agent_container_image=new-ecr-uri:v2.0.0"
```

### Infrastructure Updates

```bash
# Update Terraform module
terraform init -upgrade
terraform plan
terraform apply
```

### Configuration Changes

Edit `terraform.tfvars` and run:
```bash
terraform plan
terraform apply
```

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning**: This permanently deletes all resources including logs and monitoring data.

## Production Deployment Checklist

### Pre-Deployment
- [ ] ECR repository created and accessible
- [ ] Agent container image built and pushed
- [ ] Backend API URL configured
- [ ] Customer API key generated
- [ ] AWS permissions validated

### Deployment
- [ ] Terraform variables configured
- [ ] Infrastructure deployed successfully
- [ ] Agent container started and healthy
- [ ] Backend connectivity verified
- [ ] S3 bucket access confirmed

### Post-Deployment
- [ ] First scan job executed successfully
- [ ] CloudWatch logs flowing correctly
- [ ] Monitoring alerts configured
- [ ] Access controls reviewed
- [ ] Documentation updated

## Support

### Getting Help
- **Validation**: Check CloudWatch logs for detailed diagnostics
- **Connectivity**: Verify security groups and network configuration
- **Permissions**: Review IAM roles and policies

### Emergency Procedures
1. **Agent Failure**: Instance will auto-restart, check logs for root cause
2. **Job processing failures**: Check S3 permissions and backend connectivity
3. **Security Incident**: Immediately terminate instance via AWS Console
4. **Complete Outage**: Re-run terraform apply to restore infrastructure

---
