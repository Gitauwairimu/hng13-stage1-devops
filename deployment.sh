#!/bin/bash
set -euo pipefail

# ============================================
# Colors for output
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper functions
# ============================================
print_color() {
    echo -e "${1}${2}${NC}"
}

log_info()    { print_color "$BLUE"   "[INFO] $1"; }
log_success() { print_color "$GREEN"  "[OK]   $1"; }
log_warn()    { print_color "$YELLOW" "[WARN] $1"; }
log_error()   { print_color "$RED"    "[ERROR] $1"; }

error_exit() {
    log_error "$1"
    exit 1
}

# Input validation
validate_git_url() {
    [[ $1 =~ ^(https://github\.com/.+|git@github\.com:.+) ]] || return 1
}

validate_branch_name() {
    [[ $1 =~ ^[a-zA-Z0-9._/-]+$ ]] || return 1
}

validate_ip() {
    local ip=$1
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r a b c d <<< "$ip"
    for i in $a $b $c $d; do
        ((i >= 0 && i <= 255)) || return 1
    done
}

validate_port() {
    [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

expand_path() {
    echo "${1/#\~/$HOME}"
}

find_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    find "$ssh_dir" -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" -print 2>/dev/null || true
}

validate_ssh_key() {
    local path
    path=$(expand_path "$1")
    [ -f "$path" ] && [ -r "$path" ] && grep -q "PRIVATE KEY" "$path"
}

# User input collection
get_input() {
    local prompt=$1
    local validation_func=${2:-}
    local default_value=${3:-}
    local input_value

    while true; do
        if [ -n "$default_value" ]; then
            read -p "$prompt [$default_value]: " input_value
            input_value="${input_value:-$default_value}"
        else
            read -p "$prompt: " input_value
        fi

        if [ -z "$input_value" ]; then
            log_error "Input cannot be empty"
            continue
        fi

        if [ -n "$validation_func" ]; then
            if "$validation_func" "$input_value"; then
                echo "$input_value"
                return 0
            else
                log_error "Invalid input format"
            fi
        else
            echo "$input_value"
            return 0
        fi
    done
}

# Collect Parameters
GIT_REPO=$(get_input "Enter Git Repository URL" validate_git_url)
log_info "Git Repository set: $GIT_REPO"

print_color "$YELLOW" "Note: Your Personal Access Token (PAT) input will be hidden."
while true; do
    read -s -p "Enter Personal Access Token (PAT): " PAT
    echo
    [ -n "$PAT" ] && break || log_error "PAT cannot be empty"
done

BRANCH=$(get_input "Enter branch name" validate_branch_name "main")
SSH_USERNAME=$(get_input "Enter SSH username" "" "")
SERVER_IP=$(get_input "Enter server IP address" validate_ip "")
APP_PORT=$(get_input "Enter application port" validate_port "8080")

# SSH Key selection
log_info "Scanning for available SSH keys..."
AVAILABLE_KEYS=($(find_ssh_keys))
if [ ${#AVAILABLE_KEYS[@]} -gt 0 ]; then
    log_info "Found SSH keys:"
    for i in "${!AVAILABLE_KEYS[@]}"; do
        echo "  $((i+1)). ${AVAILABLE_KEYS[$i]}"
    done
else
    log_warn "No existing SSH keys found in ~/.ssh/"
fi

while true; do
    read -p "Enter SSH key path (or 'generate' to create new): " SSH_KEY_PATH
    [ -z "$SSH_KEY_PATH" ] && { log_error "SSH key path cannot be empty"; continue; }

    if [ "$SSH_KEY_PATH" = "generate" ]; then
        read -p "Enter email for SSH key: " ssh_email
        key_file="$HOME/.ssh/id_rsa_$(date +%Y%m%d)"
        ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$key_file" || error_exit "Failed to generate SSH key"
        SSH_KEY_PATH="$key_file"
        log_success "Generated new SSH key: $SSH_KEY_PATH"
        break
    fi

    validate_ssh_key "$SSH_KEY_PATH" && break || log_error "Invalid or unreadable SSH key path"
done

SSH_KEY_PATH=$(expand_path "$SSH_KEY_PATH")


# Clone or Update Repository
log_info "Step 2: Repository Setup"

repo_name=$(basename -s .git "$GIT_REPO")

if [[ $GIT_REPO == https://* ]]; then
    AUTH_REPO_URL="${GIT_REPO/https:\/\//https:\/\/oauth2:${PAT}@}"
else
    AUTH_REPO_URL="$GIT_REPO"
fi
# --------------------------------------------

if [ -d "$repo_name" ]; then
    cd "$repo_name" || error_exit "Cannot enter directory '$repo_name'"
    ls -al
    echo
else
    git clone -b "$BRANCH" "$AUTH_REPO_URL" "$repo_name" || error_exit "Git clone failed"
    cd "$repo_name"
fi


# Ensure correct branch
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH"
else
    git checkout -b "$BRANCH" "origin/$BRANCH" || error_exit "Failed to checkout branch $BRANCH"
fi

latest_commit=$(git log -1 --oneline)
log_success "Repository synced to latest commit: $latest_commit"

# ============================================
# Step 3: Verify Project Files
# ============================================
log_info "Step 3: Verifying project structure"

if [ -f "docker-compose.yml" ]; then
    echo "[INFO] docker-compose.yml found"
elif [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
    echo "[INFO] Dockerfile found"
else
    error_exit "No Dockerfile or docker-compose.yml found in project root"
fi


log_success "✓ Repository setup and verification complete."
log_info "Ready for Docker build and deployment steps."







# ============================================
# Step 4: SSH into Remote Server
# ============================================
log_info "Step 4: Establishing SSH connection to remote server"

# Test SSH connectivity
log_info "Testing SSH connectivity to $SSH_USERNAME@$SERVER_IP ..."
if ssh -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    "$SSH_USERNAME@$SERVER_IP" "echo 2>&1" >/dev/null 2>&1; then
    log_success "SSH connection successful."
else
    error_exit "Unable to establish SSH connection. Check IP, credentials, or key permissions."
fi

# ping or ssh Dry test
# Optional reachability check (Ping + SSH Dry-run fallback)
if ping -c 2 "$SERVER_IP" >/dev/null 2>&1; then
    log_success "Host $SERVER_IP is reachable via ping."
else
    log_warn "Host $SERVER_IP not reachable via ping. Attempting SSH dry-run..."

    # SSH Dry-run fallback
    if ssh -i "$SSH_KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -o BatchMode=yes \
        "$SSH_USERNAME@$SERVER_IP" "echo SSH_OK" >/dev/null 2>&1; then
        log_success "SSH dry-run succeeded. Continuing deployment."
    else
        error_exit "Host $SERVER_IP unreachable — SSH dry-run failed. Check IP, credentials, or firewall settings."
    fi
fi


log_info "Step 5: Preparing remote environment"

ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$SSH_USERNAME@$SERVER_IP" bash <<"EOF"
set -Eeuo pipefail

# === Helper functions ===
log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# === System update ===
log "Updating system packages..."
if sudo apt-get update -y >/dev/null && sudo apt-get upgrade -y >/dev/null; then
  ok "System packages updated."
else
  warn "Some packages failed to update."
fi

# === Install Docker ===
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker..."
  if curl -fsSL https://get.docker.com | sh; then
    ok "Docker installed successfully."
  else
    fail "Docker installation failed."
  fi
else
  ok "Docker already installed."
fi

# === Install Docker Compose (using apt) ===
if ! command -v docker-compose >/dev/null 2>&1; then
  log "Installing Docker Compose..."
  
  # Method 1: Try installing via apt (for Ubuntu/Debian)
  if sudo apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
    ok "Docker Compose plugin installed via apt."
  else
    # Method 2: Try alternative package name
    if sudo apt-get install -y docker-compose >/dev/null 2>&1; then
      ok "Docker Compose installed via apt."
    else
      # Method 3: Manual installation as fallback
      log "Attempting manual Docker Compose installation..."
      COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      
      if [ -n "$COMPOSE_VERSION" ]; then
        sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        ok "Docker Compose $COMPOSE_VERSION installed manually."
      else
        warn "Could not determine Docker Compose version — skipping installation."
      fi
    fi
  fi
else
  ok "Docker Compose already installed."
fi

# === Install Nginx ===
if ! command -v nginx >/dev/null 2>&1; then
  log "Installing Nginx..."
  if sudo apt-get install -y nginx >/dev/null; then
    ok "Nginx installed successfully."
  else
    warn "Failed to install Nginx."
  fi
else
  ok "Nginx already installed."
fi

# === Add user to Docker group ===
if id -nG "$USER" | grep -qw docker; then
  ok "User already in Docker group."
else
  log "Adding user to Docker group..."
  if sudo usermod -aG docker "$USER"; then
    ok "User added to Docker group."
  else
    warn "Failed to add user to Docker group."
  fi
fi

# === Enable and start services ===
log "Enabling and starting Docker & Nginx services..."
for svc in docker nginx; do
  sudo systemctl enable "$svc" >/dev/null 2>&1 || warn "Could not enable $svc"
  sudo systemctl restart "$svc" >/dev/null 2>&1 || warn "Failed to start $svc service"

  if systemctl is-active --quiet "$svc"; then
    ok "$svc service is active and running."
  else
    warn "$svc service not active."
  fi
done

# === Confirm versions ===
log "Confirming installation versions..."
{
  echo -n "Docker: "; docker --version 2>/dev/null || echo "Not available"
  echo -n "Docker Compose Plugin: "; docker compose version 2>/dev/null || echo "Not available"
  echo -n "Nginx: "; nginx -v 2>&1 | head -1 || echo "Not available"
} | while read -r line; do ok "$line"; done

ok "Remote environment setup complete."
EOF

log_success "✓ Remote server $SERVER_IP verified and prepared successfully."







# ============================================
# Step 6: Deploy the Dockerized Application
# ============================================
# ============================================
# Step 6: Deploy Application to Remote Server
# ============================================
# ssh -i "$SSH_KEY_PATH" \
#   -o StrictHostKeyChecking=no \
#   -o UserKnownHostsFile=/dev/null \
#   "$SSH_USERNAME@$SERVER_IP" \
#   "APP_PORT=$APP_PORT bash -s" <<'EOF'
# set -Eeuo pipefail

# log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
# ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
# warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
# fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# DEPLOY_DIR="/home/$USER/app"
# PROJECT_NAME=$(basename "$DEPLOY_DIR")

# log "Checking deployed files in $DEPLOY_DIR..."
# if [ ! -d "$DEPLOY_DIR" ]; then
#   fail "Project directory $DEPLOY_DIR not found on remote server"
# fi

# cd "$DEPLOY_DIR" || fail "Cannot enter project directory $DEPLOY_DIR"

# log "Remote Docker files:"
# ls -la | grep -iE "(dockerfile|docker-compose)" || warn "No Docker files found"

# sudo curl -sf http://localhost:$APP_PORT

# # sudo docker logs app
# # sudo docker exec app printenv APP_PORT
# sudo docker run --rm -e APP_PORT="$APP_PORT" "$PROJECT_NAME" printenv | grep APP_PORT


# log "Stopping any existing container..."
# sudo docker stop "$PROJECT_NAME" 2>/dev/null || warn "No container to stop"
# sudo docker rm "$PROJECT_NAME" 2>/dev/null || warn "No container to remove"

# log "Building Docker image..."
# if sudo docker build -t "$PROJECT_NAME" .; then
#   ok "Docker image built successfully"
# else
#   fail "Docker build failed"
# fi

# log "Running container (internal port only, $APP_PORT)..."
# # sudo docker run -d --name "$PROJECT_NAME" "$PROJECT_NAME"
# sudo docker run -d --name "$PROJECT_NAME" -e APP_PORT="$APP_PORT" -p "$APP_PORT:$APP_PORT" "$PROJECT_NAME"


# sleep 5

# log "Checking if app responds internally..."
# if sudo docker exec "$PROJECT_NAME" curl -sf http://localhost:$APP_PORT; then
#   ok "✅ App is accessible internally on port $APP_PORT"
# else
#   fail "❌ App not reachable on $APP_PORT inside container"
# fi

# log "Checking container logs for confirmation..."
# sudo docker logs "$PROJECT_NAME" | tail -20

# ok "Deployment completed successfully!"
# EOF











# # ============================================
# # Step 6: Deploy Application to Remote Server
# # ============================================
# log_info "Step 6: Deploying application to remote server"

# # First, sync project files to remote server
# log_info "Synchronizing project files to remote server..."
# if rsync -avz -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
#     --exclude '.git' \
#     --exclude 'node_modules' \
#     ./ "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/"; then
#     log_success "Project files synchronized successfully"
# else
#     log_warn "Rsync failed, using SCP as fallback..."
#     scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r ./* "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/" || error_exit "Failed to transfer project files"
# fi

# # Deploy with comprehensive debugging
# log_info "Building and deploying Docker container..."

# ssh -i "$SSH_KEY_PATH" \
#   -o StrictHostKeyChecking=no \
#   -o UserKnownHostsFile=/dev/null \
#   "$SSH_USERNAME@$SERVER_IP" << DEPLOY_EOF
# set -e

# echo -e "\033[1;34m[INFO]\033[0m Starting deployment on port $APP_PORT..."

# cd /home/\$USER/app

# echo -e "\033[1;34m[INFO]\033[0m Current directory and files:"
# pwd
# ls -la

# echo -e "\033[1;34m[INFO]\033[0m Checking Dockerfile:"
# if [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
#   echo -e "\033[1;32m[OK]\033[0m Dockerfile found"
#   cat Dockerfile 2>/dev/null || cat dockerfile 2>/dev/null | head -20
# else
#   echo -e "\033[1;31m[ERROR]\033[0m No Dockerfile found!"
#   exit 1
# fi

# echo -e "\033[1;34m[INFO]\033[0m Checking application files:"
# ls -la *.py requirements.txt 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No Python files found"

# echo -e "\033[1;34m[INFO]\033[0m Stopping any existing containers..."
# sudo docker stop hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to stop"
# sudo docker rm hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to remove"

# echo -e "\033[1;34m[INFO]\033[0m Building Docker image..."
# if sudo docker build -t hng13-stage1-devops .; then
#   echo -e "\033[1;32m[OK]\033[0m Docker image built successfully"
# else
#   echo -e "\033[1;31m[ERROR]\033[0m Docker build failed"
#   exit 1
# fi

# echo -e "\033[1;34m[INFO]\033[0m Running container in foreground first to see output..."
# sudo docker run --name hng13-stage1-devops-debug -p $APP_PORT:8000 hng13-stage1-devops &
# CONTAINER_PID=\$!
# sleep 10

# echo -e "\033[1;34m[INFO]\033[0m Checking if debug container is running..."
# if sudo docker ps | grep -q hng13-stage1-devops-debug; then
#   echo -e "\033[1;32m[OK]\033[0m Debug container is running"
#   echo -e "\033[1;34m[INFO]\033[0m Debug container logs:"
#   sudo docker logs hng13-stage1-devops-debug
# else
#   echo -e "\033[1;31m[ERROR]\033[0m Debug container failed to start"
#   echo -e "\033[1;34m[INFO]\033[0m Debug container logs (if any):"
#   sudo docker logs hng13-stage1-devops-debug 2>/dev/null || echo "No logs available"
# fi

# # Stop the debug container
# sudo docker stop hng13-stage1-devops-debug 2>/dev/null || true
# sudo docker rm hng13-stage1-devops-debug 2>/dev/null || true

# echo -e "\033[1;34m[INFO]\033[0m Now running container in detached mode..."
# if sudo docker run -d --name hng13-stage1-devops -p $APP_PORT:8000 hng13-stage1-devops; then
#   echo -e "\033[1;32m[OK]\033[0m Container started successfully"
# else
#   echo -e "\033[1;31m[ERROR]\033[0m Failed to start container"
#   echo -e "\033[1;34m[INFO]\033[0m Checking what went wrong..."
#   sudo docker logs hng13-stage1-devops 2>/dev/null || echo "No logs available"
#   exit 1
# fi

# echo -e "\033[1;34m[INFO]\033[0m Waiting for application to start..."
# sleep 15

# echo -e "\033[1;34m[INFO]\033[0m Checking container status..."
# if sudo docker ps | grep -q hng13-stage1-devops; then
#   echo -e "\033[1;32m[OK]\033[0m Container is running"
#   echo -e "\033[1;34m[INFO]\033[0m Container details:"
#   sudo docker ps | grep hng13-stage1-devops
# else
#   echo -e "\033[1;31m[ERROR]\033[0m Container is not running"
#   echo -e "\033[1;34m[INFO]\033[0m Checking why container stopped..."
#   sudo docker ps -a | grep hng13-stage1-devops
#   echo -e "\033[1;34m[INFO]\033[0m Container logs:"
#   sudo docker logs hng13-stage1-devops
#   exit 1
# fi

# echo -e "\033[1;34m[INFO]\033[0m Container logs:"
# sudo docker logs hng13-stage1-devops

# echo -e "\033[1;34m[INFO]\033[0m Testing application internally..."
# if sudo docker exec hng13-stage1-devops curl -sf http://localhost:8000 > /dev/null 2>&1; then
#   echo -e "\033[1;32m[OK]\033[0m Application is responding internally"
# else
#   echo -e "\033[1;33m[WARN]\033[0m Application not responding internally"
#   echo -e "\033[1;34m[INFO]\033[0m Recent container logs:"
#   sudo docker logs hng13-stage1-devops | tail -30
# fi

# echo -e "\033[1;34m[INFO]\033[0m Testing application externally..."
# if curl -sf http://localhost:$APP_PORT > /dev/null 2>&1; then
#   echo -e "\033[1;32m[OK]\033[0m Application is responding on port $APP_PORT"
# else
#   echo -e "\033[1;33m[WARN]\033[0m Application not responding externally yet"
#   echo -e "\033[1;34m[INFO]\033[0m Checking port binding:"
#   sudo docker port hng13-stage1-devops
#   echo -e "\033[1;34m[INFO]\033[0m Checking network:"
#   sudo netstat -tuln | grep ":$APP_PORT" || echo "Port $APP_PORT not listening"
# fi

# echo -e "\033[1;32m[OK]\033[0m Deployment completed successfully!"
# DEPLOY_EOF

# # Final health check
# log_info "Performing final health check..."
# sleep 5

# if curl -s -f --connect-timeout 30 "http://$SERVER_IP:$APP_PORT/me" >/dev/null 2>&1; then
#     log_success "✓ Application deployed and responding successfully!"
#     log_success "🎉 Your application is now live at: http://$SERVER_IP:$APP_PORT"
#     log_success "📊 Test your endpoint: curl http://$SERVER_IP:$APP_PORT/me"
# else
#     log_warn "⚠ Application may be starting up or having issues"
#     log_info "Checking remote container status..."
#     ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USERNAME@$SERVER_IP" "
#         echo '=== Container Status ==='
#         sudo docker ps -a | grep hng13-stage1-devops || echo 'Container not found'
#         echo ''
#         echo '=== Recent Logs ==='
#         sudo docker logs hng13-stage1-devops 2>/dev/null | tail -50 || echo 'No logs available'
#         echo ''
#         echo '=== Port Mapping ==='
#         sudo docker port hng13-stage1-devops 2>/dev/null || echo 'No port mapping'
#     "
#     log_success "✓ Deployment attempted - check logs above for details"
# fi





























# ============================================
# Step 6: Deploy Application to Remote Server
# ============================================
log_info "Step 6: Deploying application to remote server"

# First, sync project files to remote server
log_info "Synchronizing project files to remote server..."
if rsync -avz -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude '.git' \
    --exclude 'node_modules' \
    ./ "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/"; then
    log_success "Project files synchronized successfully"
else
    log_warn "Rsync failed, using SCP as fallback..."
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r ./* "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/" || error_exit "Failed to transfer project files"
fi

# Deploy with comprehensive debugging
log_info "Building and deploying Docker container..."

ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$SSH_USERNAME@$SERVER_IP" << DEPLOY_EOF
set -e

echo -e "\033[1;34m[INFO]\033[0m Starting deployment on port $APP_PORT..."

cd /home/\$USER/app

echo -e "\033[1;34m[INFO]\033[0m Current directory and files:"
pwd
ls -la

echo -e "\033[1;34m[INFO]\033[0m Checking Dockerfile:"
if [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
  echo -e "\033[1;32m[OK]\033[0m Dockerfile found"
  cat Dockerfile 2>/dev/null || cat dockerfile 2>/dev/null | head -20
else
  echo -e "\033[1;31m[ERROR]\033[0m No Dockerfile found!"
  exit 1
fi

echo -e "\033[1;34m[INFO]\033[0m Stopping any existing containers..."
sudo docker stop hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to stop"
sudo docker rm hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to remove"

echo -e "\033[1;34m[INFO]\033[0m Building Docker image..."
if sudo docker build -t hng13-stage1-devops .; then
  echo -e "\033[1;32m[OK]\033[0m Docker image built successfully"
else
  echo -e "\033[1;31m[ERROR]\033[0m Docker build failed"
  exit 1
fi

echo -e "\033[1;34m[INFO]\033[0m Running container..."
if sudo docker run -d --name hng13-stage1-devops -p $APP_PORT:8000 hng13-stage1-devops; then
  echo -e "\033[1;32m[OK]\033[0m Container started successfully"
  CONTAINER_ID=\$(sudo docker ps -q -f name=hng13-stage1-devops)
  echo -e "\033[1;34m[INFO]\033[0m Container ID: \$CONTAINER_ID"
else
  echo -e "\033[1;31m[ERROR]\033[0m Failed to start container"
  exit 1
fi

echo -e "\033[1;34m[INFO]\033[0m Waiting for application to start..."
sleep 10

echo -e "\033[1;34m[INFO]\033[0m ==========================================="
echo -e "\033[1;34m[INFO]\033[0m TESTING APPLICATION INSIDE HOST"
echo -e "\033[1;34m[INFO]\033[0m ==========================================="

echo -e "\033[1;34m[INFO]\033[0m 1. Checking container status..."
if sudo docker ps | grep -q hng13-stage1-devops; then
  echo -e "\033[1;32m[OK]\033[0m Container is running"
  echo -e "\033[1;34m[INFO]\033[0m Container details:"
  sudo docker ps | grep hng13-stage1-devops
else
  echo -e "\033[1;31m[ERROR]\033[0m Container is not running!"
  echo -e "\033[1;34m[INFO]\033[0m Checking stopped containers:"
  sudo docker ps -a | grep hng13-stage1-devops
  echo -e "\033[1;34m[INFO]\033[0m Container logs:"
  sudo docker logs hng13-stage1-devops
  exit 1
fi

echo -e "\033[1;34m[INFO]\033[0m 2. Checking container health..."
sudo docker inspect hng13-stage1-devops | grep -A 10 \"Health\" || echo -e "\033[1;33m[WARN]\033[0m No health check configured"

echo -e "\033[1;34m[INFO]\033[0m 3. Testing from INSIDE the container..."
if sudo docker exec hng13-stage1-devops curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
  echo -e "\033[1;32m[OK]\033[0m ✅ Application is running INSIDE container (port 8000)"
  echo -e "\033[1;34m[INFO]\033[0m Testing /me endpoint inside container:"
  sudo docker exec hng13-stage1-devops curl -s http://localhost:8000/me | head -5
else
  echo -e "\033[1;31m[ERROR]\033[0m ❌ Application NOT running inside container"
  echo -e "\033[1;34m[INFO]\033[0m Container logs:"
  sudo docker logs hng13-stage1-devops | tail -30
fi

echo -e "\033[1;34m[INFO]\033[0m 4. Testing from HOST network (container IP)..."
CONTAINER_IP=\$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hng13-stage1-devops)
echo -e "\033[1;34m[INFO]\033[0m Container IP: \$CONTAINER_IP"
if [ -n "\$CONTAINER_IP" ]; then
  if curl -s -f http://\$CONTAINER_IP:8000/ > /dev/null 2>&1; then
    echo -e "\033[1;32m[OK]\033[0m ✅ Application accessible via container IP: \$CONTAINER_IP:8000"
  else
    echo -e "\033[1;33m[WARN]\033[0m ⚠ Application not accessible via container IP"
  fi
fi

echo -e "\033[1;34m[INFO]\033[0m 5. Testing from HOST network (localhost port mapping)..."
if curl -s -f http://localhost:$APP_PORT/ > /dev/null 2>&1; then
  echo -e "\033[1;32m[OK]\033[0m ✅ Application accessible via HOST localhost:$APP_PORT"
  echo -e "\033[1;34m[INFO]\033[0m Testing /me endpoint on host:"
  curl -s http://localhost:$APP_PORT/me | head -5
else
  echo -e "\033[1;33m[WARN]\033[0m ⚠ Application not accessible via host port $APP_PORT"
fi

echo -e "\033[1;34m[INFO]\033[0m 6. Checking port mapping..."
echo -e "\033[1;34m[INFO]\033[0m Docker port mapping:"
sudo docker port hng13-stage1-devops

echo -e "\033[1;34m[INFO]\033[0m 7. Checking host network status..."
echo -e "\033[1;34m[INFO]\033[0m Host ports listening:"
sudo netstat -tuln | grep ":$APP_PORT" || echo -e "\033[1;33m[WARN]\033[0m Port $APP_PORT not listening on host"

echo -e "\033[1;34m[INFO]\033[0m 8. Recent container logs:"
sudo docker logs hng13-stage1-devops | tail -20

echo -e "\033[1;32m[OK]\033[0m Host testing completed!"
DEPLOY_EOF

# Final external health check
log_info "Performing external health check..."
sleep 5

log_info "Testing application from EXTERNAL network..."
if curl -s -f --connect-timeout 30 "http://$SERVER_IP:$APP_PORT/me" >/dev/null 2>&1; then
    log_success "✓ Application deployed and responding successfully!"
    log_success "🎉 Your application is now live at: http://$SERVER_IP:$APP_PORT"
    log_success "📊 Test your endpoint: curl http://$SERVER_IP:$APP_PORT/me"
    
    # Show actual response
    log_info "Sample response:"
    curl -s "http://$SERVER_IP:$APP_PORT/me" | head -10
else
    log_warn "⚠ Application not accessible externally yet"
    log_info "This could be due to:"
    log_info "  - Application still starting up"
    log_info "  - Firewall blocking port $APP_PORT"
    log_info "  - Network configuration"
    log_info ""
    log_info "The application is running on the host but may not be externally accessible"
    log_info "Check: sudo ufw status (on the server)"
fi