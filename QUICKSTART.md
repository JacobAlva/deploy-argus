# 🚀 Quick Start - Deploy Argus Agent in 5 Minutes

This guide gets you from zero to a running Argus agent in your AWS account in under 5 minutes.

## 📋 Prerequisites

- ✅ AWS CLI configured with admin permissions
- ✅ Terraform >= 1.5.0 installed
- ✅ Argus account with generated API key

## ⚡ 5-Minute Deployment

### Step 1: Clone and Configure
```bash
# Clone this repository
git clone https://github.com/JacobAlva/deploy-argus.git
cd deploy-argus/examples/basic-deployment

# Copy configuration template  
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (use your favorite editor)
nano terraform.tfvars
```

### Step 2: Required Configuration
Edit `terraform.tfvars` and set these **required** values:
```hcl
customer_name     = "your-company"        # Your company name
agent_api_key     = "argus_sk_..."        # From Argus dashboard  
aws_region        = "us-east-1"           # Your preferred AWS region
```

### Step 3: Deploy
```bash
# Initialize Terraform
terraform init

# Preview what will be created  
terraform plan

# Deploy the agent
terraform apply
# Type 'yes' when prompted
```

### Step 4: Verify
```bash
# Check the agent instance
terraform output agent_instance_id

# View the agent in AWS Console
aws ec2 describe-instances --instance-ids $(terraform output -raw agent_instance_id)
```

## 🎯 What Gets Created

- **EC2 Instance**: Single t3.medium instance running the Argus agent
- **IAM Role**: Minimal S3 read permissions for data scanning  
- **Security Group**: Locked-down access (HTTPS outbound only)
- **CloudWatch Logs**: Agent logs with 30-day retention
- **Secrets Manager**: Secure API key storage

## 🔒 Security Features

- ✅ **Data Sovereignty**: Your data never leaves your AWS account
- ✅ **Least Privilege**: Minimal IAM permissions (S3 read-only)
- ✅ **Encrypted Storage**: All EBS volumes encrypted at rest
- ✅ **No Inbound Access**: Agent only makes outbound connections

## 🧹 Clean Up

When you're done testing:
```bash
terraform destroy
# Type 'yes' when prompted
```

## 📞 Need Help?

- 📖 **Full Documentation**: See [README.md](README.md)
- 🔍 **Troubleshooting**: Run `./scripts/validate-deployment.sh`
- 💬 **Support**: Contact support@argus-dspm.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/argus-dspm/deploy-argus/issues)

## 🔗 Next Steps

- **Production Deployment**: See [examples/production-deployment/](../production-deployment/)
- **Multi-Region**: Deploy agents in multiple regions  
- **Monitoring**: Set up custom CloudWatch dashboards
- **Updates**: Keep agent updated with latest releases