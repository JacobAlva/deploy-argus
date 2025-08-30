#!/bin/bash
# Argus Agent EC2 Bootstrap Script
# This script configures the EC2 instance to run the Argus agent container

set -e

# Template variables from Terraform (used in configuration files)
# Bash variables for runtime use
AGENT_ID="${agent_id}"
AGENT_API_KEY_SECRET_NAME="${agent_api_key_secret_name}"
ARGUS_BACKEND_URL="${argus_backend_url}"
AGENT_CONTAINER_IMAGE="${agent_container_image}"
AGENT_LOG_LEVEL="${agent_log_level}"
HEALTH_CHECK_INTERVAL="${health_check_interval}"
AWS_REGION="${aws_region}"

# Log file for bootstrap process
BOOTSTRAP_LOG="/var/log/argus-agent-bootstrap.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$BOOTSTRAP_LOG"
}

log_message "Starting Argus Agent bootstrap process"

# Update system packages
log_message "Updating system packages"
yum update -y

# Install required packages
log_message "Installing required packages"
yum install -y \
    docker \
    aws-cli \
    awslogs \
    jq \
    curl \
    wget \
    htop \
    unzip

# Start and enable Docker
log_message "Starting Docker service"
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
log_message "Installing Docker Compose"
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create application directory
log_message "Creating application directory"
mkdir -p /opt/argus-agent
cd /opt/argus-agent

# Configure CloudWatch logs agent
log_message "Configuring CloudWatch logs"
cat > /etc/awslogs/awslogs.conf << EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/argus-agent-bootstrap.log]
file = /var/log/argus-agent-bootstrap.log
log_group_name = ${cloudwatch_log_group}
log_stream_name = {instance_id}/bootstrap
datetime_format = %Y-%m-%d %H:%M:%S

[/var/log/argus-agent/application.log]
file = /var/log/argus-agent/application.log
log_group_name = ${cloudwatch_log_group}
log_stream_name = {instance_id}/application
datetime_format = %Y-%m-%d %H:%M:%S

[/var/log/argus-agent/error.log]
file = /var/log/argus-agent/error.log
log_group_name = ${cloudwatch_log_group}
log_stream_name = {instance_id}/error
datetime_format = %Y-%m-%d %H:%M:%S
EOF

# Update awslogs region
sed -i "s/us-east-1/${aws_region}/g" /etc/awslogs/awscli.conf

# Start and enable awslogs
systemctl start awslogs
systemctl enable awslogs

# Create log directory for agent
mkdir -p /var/log/argus-agent

# Retrieve API key from Secrets Manager
log_message "Retrieving API key from Secrets Manager"
API_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "${agent_api_key_secret_name}" \
    --region "${aws_region}" \
    --query SecretString --output text)

if [ -z "$API_KEY" ]; then
    log_message "ERROR: Failed to retrieve API key from Secrets Manager"
    exit 1
fi

# Create agent configuration
log_message "Creating agent configuration"
cat > /opt/argus-agent/.env << EOF
# Argus Agent Configuration
AGENT_ID=${agent_id}
AGENT_API_KEY=$API_KEY
ARGUS_BACKEND_URL=${argus_backend_url}
AWS_DEFAULT_REGION=${aws_region}
LOG_LEVEL=${agent_log_level}
HEALTH_CHECK_INTERVAL=${health_check_interval}

# Container configuration
CONTAINER_NAME=argus-agent
RESTART_POLICY=unless-stopped

# Logging configuration
LOG_DRIVER=json-file
LOG_MAX_SIZE=10m
LOG_MAX_FILE=5
EOF

# Create Docker Compose file
log_message "Creating Docker Compose configuration"
cat > /opt/argus-agent/docker-compose.yml << EOF
version: '3.8'

services:
  argus-agent:
    image: $AGENT_CONTAINER_IMAGE
    container_name: argus-agent
    restart: unless-stopped
    environment:
      - AGENT_ID=\${agent_id}
      - AGENT_API_KEY=\${agent_api_key_secret_name}
      - ARGUS_BACKEND_URL=\${argus_backend_url}
      - AWS_DEFAULT_REGION=\${aws_region}
      - LOG_LEVEL=\${agent_log_level}
      - HEALTH_CHECK_INTERVAL=\${health_check_interval}
    volumes:
      - /var/log/argus-agent:/app/logs
      - /tmp:/tmp
    ports:
      - "8080:8080"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF

# Create systemd service for agent
log_message "Creating systemd service"
cat > /etc/systemd/system/argus-agent.service << EOF
[Unit]
Description=Argus Agent Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/opt/argus-agent
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create health check script
log_message "Creating health check script"
cat > /opt/argus-agent/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for Argus Agent

HEALTH_URL="http://localhost:8080/health"
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f -s "$HEALTH_URL" > /dev/null 2>&1; then
        echo "Agent is healthy"
        exit 0
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Health check failed (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo "Agent health check failed after $MAX_RETRIES attempts"
exit 1
EOF

chmod +x /opt/argus-agent/health-check.sh

# Create log rotation configuration
log_message "Configuring log rotation"
cat > /etc/logrotate.d/argus-agent << EOF
/var/log/argus-agent/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Pull the latest agent container image
log_message "Pulling Argus agent container image"
cd /opt/argus-agent
docker-compose pull

# Enable and start the agent service
log_message "Starting Argus agent service"
systemctl daemon-reload
systemctl enable argus-agent.service
systemctl start argus-agent.service

# Wait for agent to be healthy
log_message "Waiting for agent to become healthy"
sleep 30
/opt/argus-agent/health-check.sh

if [ $? -eq 0 ]; then
    log_message "Argus Agent bootstrap completed successfully"
    
    # Send success signal to CloudFormation (if stack exists)
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    log_message "Instance $INSTANCE_ID successfully configured with Argus Agent"
else
    log_message "ERROR: Argus Agent failed to start properly"
    exit 1
fi

# Create maintenance scripts
log_message "Creating maintenance scripts"
cat > /opt/argus-agent/update-agent.sh << 'EOF'
#!/bin/bash
# Script to update Argus agent to latest version

cd /opt/argus-agent
docker-compose pull
docker-compose up -d --force-recreate
EOF

cat > /opt/argus-agent/restart-agent.sh << 'EOF'
#!/bin/bash
# Script to restart Argus agent service

systemctl restart argus-agent.service
EOF

chmod +x /opt/argus-agent/update-agent.sh
chmod +x /opt/argus-agent/restart-agent.sh

# Setup automatic updates (optional)
cat > /etc/cron.d/argus-agent-update << EOF
# Update Argus agent weekly at 2 AM on Sunday
0 2 * * 0 root /opt/argus-agent/update-agent.sh
EOF

log_message "Argus Agent EC2 instance bootstrap completed successfully"