# DevOps Deployment Automation Script
A comprehensive, POSIX-compliant bash script for automating the deployment of applications to remote servers. This script handles everything from repository cloning to Docker container deployment and Nginx reverse proxy configuration.


# 🚀 Features
Automated Deployment: Full CI/CD pipeline in a single script

Multi-Platform Support: Works with any Git repository (HTTPS/SSH)

Docker Integration: Automated container building and deployment

Nginx Reverse Proxy: Automatic configuration with SSL readiness

Comprehensive Validation: End-to-end deployment verification

Idempotent Operations: Safe for repeated executions

Detailed Logging: Timestamped log files for debugging

Error Handling: Robust error recovery and cleanup


# 📋 Prerequisites
Local Machine
Bash 4.0+
Git
SSH client
curl
Remote Server
Ubuntu/Debian-based OS

SSH access with sudo privileges

Open ports: 22 (SSH), 80 (HTTP), and your application port




# 🛠️ Installation
Make the script executable:

```
chmod +x deploy.sh
```

🔧 What the Script Does
# Step 1: Parameter Collection
Validates all user inputs

Generates SSH keys if needed

Securely handles credentials

# Step 2: Repository Setup
Clones or updates the Git repository

Checks out the specified branch

Verifies project structure (Dockerfile/docker-compose.yml)

# Step 3: Server Preparation
Updates system packages

Installs Docker and Docker Compose

Installs and configures Nginx

Adds user to Docker group

Starts and enables services

# Step 4: Application Deployment
Synchronizes project files to server

Builds Docker image with specified port

Runs container with proper port mapping

Validates container health

# Step 5: Nginx Configuration
Sets up reverse proxy on port 80

Configures proper headers and timeouts

Tests configuration and reloads Nginx

Provides SSL-ready configuration template

# Step 6: Validation
Verifies Docker container status

Tests application responsiveness

Confirms Nginx proxy functionality

Performs external access tests

🗂️ Project Structure
```
deployment-project/
├── deploy.sh                 # Main deployment script
├── deploy_YYYYMMDD_HHMMSS.log # Generated log files
├── backup_YYYYMMDD_HHMMSS/   # Backup directories (temporary)
└── README.md                # This file
```
# 🔐 Security Features
Secure Credential Handling: PAT input is hidden

SSH Key Validation: Verifies key format and permissions

Input Validation: Comprehensive validation for all parameters

Cleanup: Automatic removal of temporary files

Error Isolation: Failures don't expose sensitive information

# 📊 Logging
The script creates detailed log files with timestamps:

Location: deploy_YYYYMMDD_HHMMSS.log

Levels: INFO, SUCCESS, WARN, ERROR

Contents: All operations, timings, and error details

Example log entry:

```
[2024-01-15 10:30:45] [INFO] Starting deployment script: deploy.sh
[2024-01-15 10:31:02] [SUCCESS] Application deployed successfully
```
# 🛠️ Customization
Environment Variables
All parameters can be pre-set as environment variables for automation:

```
export GIT_REPO="your_repo_url"
export PAT="your_token"
export BRANCH="develop"
export SSH_USERNAME="deploy-user"
export SERVER_IP="your.server.ip"
export APP_PORT="3000"
export SSH_KEY_PATH="/path/to/ssh/key"
```
Application Port
The script uses the specified port for:

Docker container internal port

Host port mapping

Nginx reverse proxy target

Nginx Configuration
The generated Nginx config includes:

HTTP to HTTPS redirect readiness

Security headers

Proper proxy settings

Health check endpoint

# 🐛 Troubleshooting
Common Issues
SSH Connection Failed

Verify SSH key permissions: 
```
chmod 600 ~/.ssh/your_key
```
Check server firewall settings

Ensure SSH service is running on server

Docker Build Failed

Check Dockerfile exists in repository root

Verify network connectivity for Docker base images

Review build logs in generated log file

Nginx Configuration Error

Check if port is already in use

Verify Nginx syntax: 
```
sudo nginx -t
```
Ensure Nginx service is running

Application Not Accessible

Check container logs: sudo docker logs hng13-stage1-devops

Verify port mapping: sudo docker port hng13-stage1-devops

Test direct access: 
```
curl http://server_ip:app_port
```

Debug Mode
For detailed debugging, run with:

```
bash -x deploy.sh
```
# 🔄 Idempotency
The script is designed to be safely re-runnable:

Repository: Pulls latest changes if directory exists

Containers: Stops and removes existing containers before deployment

Nginx: Replaces configuration files completely

Backups: Creates backups before destructive operations

# 📞 Support
For issues and questions:

Check the generated log file for detailed error information

Verify all prerequisites are met

Ensure network connectivity to the target server

Review the troubleshooting section above