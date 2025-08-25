# Argus Agent Basic Deployment Example

This example demonstrates a simple, single-instance deployment of the Argus agent suitable for most customer environments.

## What This Example Deploys

- **Single EC2 Instance**: t3.medium instance running the Argus agent
- **IAM Role & Policies**: Least-privilege permissions for S3 access
- **Security Group**: Locked-down network access (HTTPS outbound only)
- **Secrets Manager**: Secure storage of agent API key
- **CloudWatch Logging**: Structured logging with 30-day retention
- **Monitoring Dashboard**: Basic CloudWatch dashboard and alarms

## Prerequisites

1. **AWS CLI**: Configured with appropriate credentials
2. **Terraform**: Version 1.5 or higher
3. **Agent API Key**: Obtained from Argus SaaS platform

## Quick Deploy

### 1. Set Required Variables

Create a `terraform.tfvars` file:

```hcl
customer_name = "your-company-name"
agent_api_key = "your-secure-api-key-here"
aws_region    = "us-east-1"
```

### 2. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify Deployment

```bash
# Check instance status
terraform output agent_instance_id
aws ec2 describe-instances --instance-ids $(terraform output -raw agent_instance_id)

# Check agent logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name $(terraform output -raw agent_instance_id)/bootstrap
```

## Configuration Options

### Basic Configuration

```hcl
# terraform.tfvars
customer_name = "acme-corp"
agent_api_key = "your-api-key"
aws_region    = "us-west-2"
instance_type = "t3.large"
environment   = "prod"
```

### Development Configuration

```hcl
# terraform.tfvars for development
customer_name     = "acme-dev"
agent_api_key     = "dev-api-key"
environment       = "dev"
instance_type     = "t3.small"
enable_ssh_access = true
key_pair_name     = "my-keypair"
allowed_cidr_blocks = ["10.0.0.0/8"]  # Your office network
```

## Outputs

After deployment, you'll get these important outputs:

| Output | Description | Usage |
|--------|-------------|-------|
| `agent_instance_id` | EC2 instance ID | For monitoring and troubleshooting |
| `agent_role_arn` | IAM role ARN | For cross-account access setup |
| `external_id` | Security external ID | For backend registration |
| `cloudwatch_log_group_name` | Log group name | For log monitoring |

## Post-Deployment Steps

### 1. Verify Agent Health

```bash
# Check if agent is running
INSTANCE_ID=$(terraform output -raw agent_instance_id)
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID

# Check application logs
LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)
aws logs describe-log-streams --log-group-name $LOG_GROUP
```

### 2. Register Agent with Backend

The agent will automatically register itself using the provided API key. You can verify this in the Argus dashboard.

### 3. Test Scan Job

Once registered, trigger a test scan from the Argus dashboard to verify end-to-end functionality.

## Monitoring

### CloudWatch Dashboard

A CloudWatch dashboard is automatically created with:
- EC2 instance metrics (CPU, memory, network)
- Agent application logs
- Custom metrics for scan jobs

Access it at: AWS Console → CloudWatch → Dashboards → ArgusAgent-[customer-name]

### Alerts

Built-in alerts are configured for:
- Instance health checks
- High CPU utilization (>80%)
- Application errors
- API communication failures

### Log Analysis

Use CloudWatch Insights to analyze agent logs:

```sql
fields @timestamp, @message, level
| filter level = "ERROR"
| sort @timestamp desc
| limit 100
```

## Troubleshooting

### Common Issues

#### 1. Instance Launch Failure

```bash
# Check for service limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A

# Check subnet capacity
aws ec2 describe-subnets --subnet-ids $(terraform show -json | jq -r '.values.root_module.child_modules[0].resources[] | select(.address=="aws_subnet.argus_subnet[0]") | .values.id')
```

#### 2. Agent Not Starting

```bash
# Check bootstrap logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name $(terraform output -raw agent_instance_id)/bootstrap \
  --start-from-head
```

#### 3. Permission Issues

```bash
# Validate IAM role
ROLE_ARN=$(terraform output -raw agent_role_arn)
aws iam get-role --role-name $(basename $ROLE_ARN)

# Test S3 access
aws sts assume-role --role-arn $ROLE_ARN --role-session-name test-session --external-id $(terraform output -raw external_id)
```

### Getting Help

1. **Validation**: Run the deployment validation script
2. **Logs**: Check CloudWatch logs for detailed error information  
3. **Configuration**: Verify terraform.tfvars contains correct values
4. **Permissions**: Ensure AWS credentials have required permissions

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note**: This will permanently delete all resources including logs and monitoring data.

## Next Steps

After successful deployment:

1. **Scale Up**: Consider the [production deployment example](../production-deployment/) for high availability
2. **Multi-Region**: Deploy agents in multiple regions for geographic distribution
3. **Monitoring**: Set up additional custom metrics and alerts as needed
4. **Automation**: Integrate deployment into your CI/CD pipeline