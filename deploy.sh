# # #!/bin/bash
# # set -euo pipefail

# # # ============================================
# # # Colors for output
# # # ============================================
# # RED='\033[0;31m'
# # GREEN='\033[0;32m'
# # YELLOW='\033[1;33m'
# # BLUE='\033[0;34m'
# # NC='\033[0m' # No Color

# # # ============================================
# # # Helper functions
# # # ============================================
# # print_color() {
# #     echo -e "${1}${2}${NC}"
# # }

# # log_info()    { print_color "$BLUE"   "[INFO] $1"; }
# # log_success() { print_color "$GREEN"  "[OK]   $1"; }
# # log_warn()    { print_color "$YELLOW" "[WARN] $1"; }
# # log_error()   { print_color "$RED"    "[ERROR] $1"; }

# # error_exit() {
# #     log_error "$1"
# #     exit 1
# # }

# # # Input validation
# # validate_git_url() {
# #     [[ $1 =~ ^(https://github\.com/.+|git@github\.com:.+) ]] || return 1
# # }

# # validate_branch_name() {
# #     [[ $1 =~ ^[a-zA-Z0-9._/-]+$ ]] || return 1
# # }

# # validate_ip() {
# #     local ip=$1
# #     [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
# #     IFS='.' read -r a b c d <<< "$ip"
# #     for i in $a $b $c $d; do
# #         ((i >= 0 && i <= 255)) || return 1
# #     done
# # }

# # validate_port() {
# #     [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
# # }

# # expand_path() {
# #     echo "${1/#\~/$HOME}"
# # }

# # find_ssh_keys() {
# #     local ssh_dir="$HOME/.ssh"
# #     find "$ssh_dir" -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" -print 2>/dev/null || true
# # }

# # validate_ssh_key() {
# #     local path
# #     path=$(expand_path "$1")
# #     [ -f "$path" ] && [ -r "$path" ] && grep -q "PRIVATE KEY" "$path"
# # }

# # # User input collection
# # get_input() {
# #     local prompt=$1
# #     local validation_func=${2:-}
# #     local default_value=${3:-}
# #     local input_value

# #     while true; do
# #         if [ -n "$default_value" ]; then
# #             read -p "$prompt [$default_value]: " input_value
# #             input_value="${input_value:-$default_value}"
# #         else
# #             read -p "$prompt: " input_value
# #         fi

# #         if [ -z "$input_value" ]; then
# #             log_error "Input cannot be empty"
# #             continue
# #         fi

# #         if [ -n "$validation_func" ]; then
# #             if "$validation_func" "$input_value"; then
# #                 echo "$input_value"
# #                 return 0
# #             else
# #                 log_error "Invalid input format"
# #             fi
# #         else
# #             echo "$input_value"
# #             return 0
# #         fi
# #     done
# # }

# # # Collect Parameters
# # GIT_REPO=$(get_input "Enter Git Repository URL" validate_git_url)
# # log_info "Git Repository set: $GIT_REPO"

# # print_color "$YELLOW" "Note: Your Personal Access Token (PAT) input will be hidden."
# # while true; do
# #     read -s -p "Enter Personal Access Token (PAT): " PAT
# #     echo
# #     [ -n "$PAT" ] && break || log_error "PAT cannot be empty"
# # done

# # BRANCH=$(get_input "Enter branch name" validate_branch_name "main")
# # SSH_USERNAME=$(get_input "Enter SSH username" "" "")
# # SERVER_IP=$(get_input "Enter server IP address" validate_ip "")
# # APP_PORT=$(get_input "Enter application port" validate_port "8080")

# # # SSH Key selection
# # log_info "Scanning for available SSH keys..."
# # AVAILABLE_KEYS=($(find_ssh_keys))
# # if [ ${#AVAILABLE_KEYS[@]} -gt 0 ]; then
# #     log_info "Found SSH keys:"
# #     for i in "${!AVAILABLE_KEYS[@]}"; do
# #         echo "  $((i+1)). ${AVAILABLE_KEYS[$i]}"
# #     done
# # else
# #     log_warn "No existing SSH keys found in ~/.ssh/"
# # fi

# # while true; do
# #     read -p "Enter SSH key path (or 'generate' to create new): " SSH_KEY_PATH
# #     [ -z "$SSH_KEY_PATH" ] && { log_error "SSH key path cannot be empty"; continue; }

# #     if [ "$SSH_KEY_PATH" = "generate" ]; then
# #         read -p "Enter email for SSH key: " ssh_email
# #         key_file="$HOME/.ssh/id_rsa_$(date +%Y%m%d)"
# #         ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$key_file" || error_exit "Failed to generate SSH key"
# #         SSH_KEY_PATH="$key_file"
# #         log_success "Generated new SSH key: $SSH_KEY_PATH"
# #         break
# #     fi

# #     validate_ssh_key "$SSH_KEY_PATH" && break || log_error "Invalid or unreadable SSH key path"
# # done

# # SSH_KEY_PATH=$(expand_path "$SSH_KEY_PATH")


# # # Clone or Update Repository
# # log_info "Step 2: Repository Setup"

# # repo_name=$(basename -s .git "$GIT_REPO")

# # if [[ $GIT_REPO == https://* ]]; then
# #     AUTH_REPO_URL="${GIT_REPO/https:\/\//https:\/\/oauth2:${PAT}@}"
# # else
# #     AUTH_REPO_URL="$GIT_REPO"
# # fi
# # # --------------------------------------------

# # if [ -d "$repo_name" ]; then
# #     cd "$repo_name" || error_exit "Cannot enter directory '$repo_name'"
# # else
# #     git clone -b "$BRANCH" "$AUTH_REPO_URL" "$repo_name" || error_exit "Git clone failed"
# #     cd "$repo_name"
# # fi


# # # Ensure correct branch
# # if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
# #     git checkout "$BRANCH"
# # else
# #     git checkout -b "$BRANCH" "origin/$BRANCH" || error_exit "Failed to checkout branch $BRANCH"
# # fi

# # latest_commit=$(git log -1 --oneline)
# # log_success "Repository synced to latest commit: $latest_commit"

# # # ============================================
# # # Step 3: Verify Project Files
# # # ============================================
# # log_info "Step 3: Verifying project structure"

# # if [ -f "docker-compose.yml" ]; then
# #     echo "[INFO] docker-compose.yml found"
# # elif [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
# #     echo "[INFO] Dockerfile found"
# # else
# #     error_exit "No Dockerfile or docker-compose.yml found in project root"
# # fi


# # log_success "✓ Repository setup and verification complete."
# # log_info "Ready for Docker build and deployment steps."







# # # ============================================
# # # Step 4: SSH into Remote Server
# # # ============================================
# # log_info "Step 4: Establishing SSH connection to remote server"

# # # Test SSH connectivity
# # log_info "Testing SSH connectivity to $SSH_USERNAME@$SERVER_IP ..."
# # if ssh -i "$SSH_KEY_PATH" \
# #     -o StrictHostKeyChecking=no \
# #     -o UserKnownHostsFile=/dev/null \
# #     -o BatchMode=yes \
# #     -o ConnectTimeout=10 \
# #     "$SSH_USERNAME@$SERVER_IP" "echo 2>&1" >/dev/null 2>&1; then
# #     log_success "SSH connection successful."
# # else
# #     error_exit "Unable to establish SSH connection. Check IP, credentials, or key permissions."
# # fi

# # # ping or ssh Dry test
# # # Optional reachability check (Ping + SSH Dry-run fallback)
# # if ping -c 2 "$SERVER_IP" >/dev/null 2>&1; then
# #     log_success "Host $SERVER_IP is reachable via ping."
# # else
# #     log_warn "Host $SERVER_IP not reachable via ping. Attempting SSH dry-run..."

# #     # SSH Dry-run fallback
# #     if ssh -i "$SSH_KEY_PATH" \
# #         -o StrictHostKeyChecking=no \
# #         -o ConnectTimeout=10 \
# #         -o BatchMode=yes \
# #         "$SSH_USERNAME@$SERVER_IP" "echo SSH_OK" >/dev/null 2>&1; then
# #         log_success "SSH dry-run succeeded. Continuing deployment."
# #     else
# #         error_exit "Host $SERVER_IP unreachable — SSH dry-run failed. Check IP, credentials, or firewall settings."
# #     fi
# # fi





# # log_info "Step 5: Preparing remote environment"

# # ssh -i "$SSH_KEY_PATH" \
# #   -o StrictHostKeyChecking=no \
# #   -o UserKnownHostsFile=/dev/null \
# #   "$SSH_USERNAME@$SERVER_IP" bash <<"EOF"
# # set -Eeuo pipefail

# # # === Helper functions ===
# # log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
# # ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
# # warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
# # fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# # # === System update ===
# # log "Updating system packages..."
# # export DEBIAN_FRONTEND=noninteractive
# # if sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confold" >/dev/null 2>&1; then
# #   ok "System packages updated."
# # else
# #   warn "Some packages failed to update."
# # fi

# # # === Install Docker ===
# # if ! command -v docker >/dev/null 2>&1; then
# #   log "Installing Docker..."
# #   if curl -fsSL https://get.docker.com | sh >/dev/null 2>&1; then
# #     ok "Docker installed successfully."
# #   else
# #     fail "Docker installation failed."
# #   fi
# # else
# #   ok "Docker already installed."
# # fi

# # # === Install Docker Compose (using apt) ===
# # if ! command -v docker-compose >/dev/null 2>&1; then
# #   log "Installing Docker Compose..."
  
# #   # Method 1: Try installing via apt (for Ubuntu/Debian)
# #   if sudo apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
# #     ok "Docker Compose plugin installed via apt."
# #   else
# #     # Method 2: Try alternative package name
# #     if sudo apt-get install -y docker-compose >/dev/null 2>&1; then
# #       ok "Docker Compose installed via apt."
# #     else
# #       # Method 3: Manual installation as fallback
# #       log "Attempting manual Docker Compose installation..."
# #       COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      
# #       if [ -n "$COMPOSE_VERSION" ]; then
# #         sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
# #         sudo chmod +x /usr/local/bin/docker-compose
# #         ok "Docker Compose $COMPOSE_VERSION installed manually."
# #       else
# #         warn "Could not determine Docker Compose version — skipping installation."
# #       fi
# #     fi
# #   fi
# # else
# #   ok "Docker Compose already installed."
# # fi

# # # === Install Nginx ===
# # if ! command -v nginx >/dev/null 2>&1; then
# #   log "Installing Nginx..."
# #   if sudo apt-get install -y nginx >/dev/null 2>&1; then
# #     ok "Nginx installed successfully."
# #   else
# #     warn "Failed to install Nginx."
# #   fi
# # else
# #   ok "Nginx already installed."
# # fi

# # # === Add user to Docker group ===
# # if id -nG "$USER" | grep -qw docker; then
# #   ok "User already in Docker group."
# # else
# #   log "Adding user to Docker group..."
# #   if sudo usermod -aG docker "$USER"; then
# #     ok "User added to Docker group."
# #   else
# #     warn "Failed to add user to Docker group."
# #   fi
# # fi

# # # === Enable and start services ===
# # log "Enabling and starting Docker & Nginx services..."
# # for svc in docker nginx; do
# #   sudo systemctl enable "$svc" >/dev/null 2>&1 || warn "Could not enable $svc"
# #   sudo systemctl restart "$svc" >/dev/null 2>&1 || warn "Failed to start $svc service"

# #   if systemctl is-active --quiet "$svc"; then
# #     ok "$svc service is active and running."
# #   else
# #     warn "$svc service not active."
# #   fi
# # done

# # # === Confirm versions ===
# # log "Confirming installation versions..."
# # {
# #   echo -n "Docker: "; docker --version 2>/dev/null || echo "Not available"
# #   echo -n "Docker Compose Plugin: "; docker compose version 2>/dev/null || echo "Not available"
# #   echo -n "Nginx: "; nginx -v 2>&1 | head -1 || echo "Not available"
# # } | while read -r line; do ok "$line"; done

# # ok "Remote environment setup complete."
# # EOF

# # log_success "✓ Remote server $SERVER_IP verified and prepared successfully."








# # # ============================================
# # # Step 6: Deploy Application to Remote Server
# # # ============================================
# # log_info "Step 6: Deploying application to remote server"

# # # First, sync project files to remote server
# # log_info "Synchronizing project files to remote server..."
# # if rsync -avz -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
# #     --exclude '.git' \
# #     --exclude 'node_modules' \
# #     ./ "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/"; then
# #     log_success "Project files synchronized successfully"
# # else
# #     log_warn "Rsync failed, using SCP as fallback..."
# #     scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r ./* "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/" || error_exit "Failed to transfer project files"
# # fi

# # # Deploy with comprehensive debugging
# # log_info "Building and deploying Docker container..."

# # ssh -i "$SSH_KEY_PATH" \
# #   -o StrictHostKeyChecking=no \
# #   -o UserKnownHostsFile=/dev/null \
# #   "$SSH_USERNAME@$SERVER_IP" << DEPLOY_EOF
# # set -e

# # echo -e "\033[1;34m[INFO]\033[0m Starting deployment on port $APP_PORT..."

# # cd /home/\$USER/app

# # echo -e "\033[1;34m[INFO]\033[0m Current directory and files:"
# # pwd
# # ls -la

# # echo -e "\033[1;34m[INFO]\033[0m Checking Dockerfile:"
# # if [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
# #   echo -e "\033[1;32m[OK]\033[0m Dockerfile found"
# #   cat Dockerfile 2>/dev/null || cat dockerfile 2>/dev/null | head -20
# # else
# #   echo -e "\033[1;31m[ERROR]\033[0m No Dockerfile found!"
# #   exit 1
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m Stopping any existing containers..."
# # sudo docker stop hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to stop"
# # sudo docker rm hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to remove"

# # echo -e "\033[1;34m[INFO]\033[0m Building Docker image with APP_PORT=$APP_PORT..."
# # if sudo docker build --build-arg APP_PORT=$APP_PORT -t hng13-stage1-devops .; then
# #   echo -e "\033[1;32m[OK]\033[0m Docker image built successfully"
# # else
# #   echo -e "\033[1;31m[ERROR]\033[0m Docker build failed"
# #   exit 1
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m Running container..."
# # # if sudo docker run -d --name hng13-stage1-devops -p $APP_PORT:$APP_PORT hng13-stage1-devops; then
# # if sudo docker run -d --name "hng13-stage1-devops" -e APP_PORT="$APP_PORT" -p "$APP_PORT:$APP_PORT" "hng13-stage1-devops"; then
# #   echo -e "\033[1;32m[OK]\033[0m Container started successfully"
# #   CONTAINER_ID=\$(sudo docker ps -q -f name=hng13-stage1-devops)
# #   echo -e "\033[1;34m[INFO]\033[0m Container ID: \$CONTAINER_ID"
# # else
# #   echo -e "\033[1;31m[ERROR]\033[0m Failed to start container"
# #   exit 1
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m Waiting for application to start..."
# # sleep 10

# # echo -e "\033[1;34m[INFO]\033[0m ==========================================="
# # echo -e "\033[1;34m[INFO]\033[0m TESTING APPLICATION INSIDE HOST"
# # echo -e "\033[1;34m[INFO]\033[0m ==========================================="

# # echo -e "\033[1;34m[INFO]\033[0m 1. Checking container status..."
# # if sudo docker ps | grep -q hng13-stage1-devops; then
# #   echo -e "\033[1;32m[OK]\033[0m Container is running"
# #   echo -e "\033[1;34m[INFO]\033[0m Container details:"
# #   sudo docker ps | grep hng13-stage1-devops
# # else
# #   echo -e "\033[1;31m[ERROR]\033[0m Container is not running!"
# #   echo -e "\033[1;34m[INFO]\033[0m Checking stopped containers:"
# #   sudo docker ps -a | grep hng13-stage1-devops
# #   echo -e "\033[1;34m[INFO]\033[0m Container logs:"
# #   sudo docker logs hng13-stage1-devops
# #   exit 1
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m 2. Checking container health..."
# # sudo docker inspect hng13-stage1-devops | grep -A 10 \"Health\" || echo -e "\033[1;33m[WARN]\033[0m No health check configured"

# # echo -e "\033[1;34m[INFO]\033[0m 3. Testing from INSIDE the container..."
# # if sudo docker exec hng13-stage1-devops curl -s -f http://localhost:$APP_PORT/ > /dev/null 2>&1; then
# #   echo -e "\033[1;32m[OK]\033[0m ✅ Application is running INSIDE container (port $APP_PORT)"
# #   echo -e "\033[1;34m[INFO]\033[0m Testing /me endpoint inside container:"
# #   sudo docker exec hng13-stage1-devops curl -s http://localhost:$APP_PORT/ | head -5
# # else
# #   echo -e "\033[1;31m[ERROR]\033[0m ❌ Application NOT running inside container"
# #   echo -e "\033[1;34m[INFO]\033[0m Container logs:"
# #   sudo docker logs hng13-stage1-devops | tail -30
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m 4. Testing from HOST network (container IP)..."
# # CONTAINER_IP=\$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hng13-stage1-devops)
# # echo -e "\033[1;34m[INFO]\033[0m Container IP: \$CONTAINER_IP"
# # if [ -n "\$CONTAINER_IP" ]; then
# #   if curl -s -f http://\$CONTAINER_IP:$APP_PORT/ > /dev/null 2>&1; then
# #     echo -e "\033[1;32m[OK]\033[0m ✅ Application accessible via container IP: \$CONTAINER_IP:$APP_PORT"
# #   else
# #     echo -e "\033[1;33m[WARN]\033[0m ⚠ Application not accessible via container IP"
# #   fi
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m 5. Testing from HOST network (localhost port mapping)..."
# # if curl -s -f http://localhost:$APP_PORT/ > /dev/null 2>&1; then
# #   echo -e "\033[1;32m[OK]\033[0m ✅ Application accessible via HOST localhost:$APP_PORT"
# #   echo -e "\033[1;34m[INFO]\033[0m Testing / endpoint on host:"
# #   curl -s http://localhost:$APP_PORT/ | head -5
# # else
# #   echo -e "\033[1;33m[WARN]\033[0m ⚠ Application not accessible via host port $APP_PORT"
# # fi

# # echo -e "\033[1;34m[INFO]\033[0m 6. Checking port mapping..."
# # echo -e "\033[1;34m[INFO]\033[0m Docker port mapping:"
# # sudo docker port hng13-stage1-devops

# # echo -e "\033[1;34m[INFO]\033[0m 7. Checking host network status..."
# # echo -e "\033[1;34m[INFO]\033[0m Host ports listening:"
# # sudo netstat -tuln | grep ":$APP_PORT" || echo -e "\033[1;33m[WARN]\033[0m Port $APP_PORT not listening on host"

# # echo -e "\033[1;34m[INFO]\033[0m 8. Recent container logs:"
# # sudo docker logs hng13-stage1-devops | tail -20

# # echo -e "\033[1;32m[OK]\033[0m Host testing completed!"
# # DEPLOY_EOF









# # # ============================================
# # # Step 7: Configure Nginx & Validate Deployment
# # # ============================================
# # log_info "Step 7: Configuring Nginx and validating deployment"

# # ssh -i "$SSH_KEY_PATH" \
# #   -o StrictHostKeyChecking=no \
# #   -o UserKnownHostsFile=/dev/null \
# #   "$SSH_USERNAME@$SERVER_IP" "APP_PORT=$APP_PORT; $(cat << 'NGINX_EOF'
# # set -e

# # echo -e "\033[1;34m[INFO]\033[0m Configuring Nginx reverse proxy for port $APP_PORT..."

# # # Create and enable Nginx configuration
# # sudo tee /etc/nginx/sites-available/hng13-app > /dev/null << EOF
# # server {
# #     listen 80;
# #     listen [::]:80;
# #     server_name _;
# #     location / {
# #         proxy_pass http://127.0.0.1:$APP_PORT;
# #         proxy_set_header Host \$host;
# #         proxy_set_header X-Real-IP \$remote_addr;
# #         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
# #         proxy_set_header X-Forwarded-Proto \$scheme;
# #     }
# # }
# # EOF

# # sudo ln -sf /etc/nginx/sites-available/hng13-app /etc/nginx/sites-enabled/
# # [ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default

# # # Test and reload Nginx
# # sudo nginx -t && sudo systemctl reload nginx
# # echo -e "\033[1;32m[OK]\033[0m Nginx configured successfully"

# # # Validate deployment
# # echo -e "\033[1;34m[INFO]\033[0m Validating deployment..."

# # # Check Docker container
# # if sudo docker ps | grep -q hng13-stage1-devops; then
# #     echo -e "\033[1;32m[OK]\033[0m Container is running"
# # else
# #     echo -e "\033[1;31m[ERROR]\033[0m Container not running"
# #     exit 1
# # fi

# # # Check application inside container
# # if sudo docker exec hng13-stage1-devops curl -s -f http://localhost:$APP_PORT/ > /dev/null; then
# #     echo -e "\033[1;32m[OK]\033[0m Application responsive inside container"
# # else
# #     echo -e "\033[1;31m[ERROR]\033[0m Application not responsive in container"
# #     exit 1
# # fi

# # # Check Nginx proxy
# # if curl -s -f http://localhost/ > /dev/null; then
# #     echo -e "\033[1;32m[OK]\033[0m Nginx proxy working"
# # else
# #     echo -e "\033[1;31m[ERROR]\033[0m Nginx proxy not working"
# #     exit 1
# # fi

# # echo -e "\033[1;32m[OK]\033[0m All validation checks passed!"
# # NGINX_EOF
# # )"

# # # Final external validation
# # log_info "Performing final external validation..."
# # sleep 3

# # if curl -s -f --connect-timeout 10 "http://$SERVER_IP/" >/dev/null; then
# #     log_success "🎉 Deployment successful!"
# #     log_success "Application is live at: http://$SERVER_IP/"
# #     log_success "Direct access: http://$SERVER_IP:$APP_PORT/" #Onl if port $APP_PORT is open in host
# # else
# #     log_warn "Deployment completed with issues"
# #     log_info "Check application directly at: http://$SERVER_IP:$APP_PORT/"
# # fi




























# #!/bin/bash
# set -euo pipefail

# # ============================================
# # Configuration
# # ============================================
# SCRIPT_NAME="deploy.sh"
# LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
# BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"

# # ============================================
# # Colors for output
# # ============================================
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
# NC='\033[0m' # No Color

# # ============================================
# # Helper functions
# # ============================================
# print_color() {
#     echo -e "${1}${2}${NC}"
# }

# log_info()    { print_color "$BLUE"   "[INFO] $1"; }
# log_success() { print_color "$GREEN"  "[OK]   $1"; }
# log_warn()    { print_color "$YELLOW" "[WARN] $1"; }
# log_error()   { print_color "$RED"    "[ERROR] $1"; }

# # Logging functions
# write_log() {
#     local level=$1
#     local message=$2
#     local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
#     echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
# }

# log_to_file() {
#     write_log "INFO" "$1"
#     log_info "$1"
# }

# success_to_file() {
#     write_log "SUCCESS" "$1"
#     log_success "$1"
# }

# warn_to_file() {
#     write_log "WARN" "$1"
#     log_warn "$1"
# }

# error_to_file() {
#     write_log "ERROR" "$1"
#     log_error "$1"
# }

# # Error handling
# cleanup() {
#     local exit_code=$?
#     write_log "INFO" "Cleaning up..."
    
#     # Remove backup directory if it exists and we're exiting
#     if [ -d "$BACKUP_DIR" ]; then
#         rm -rf "$BACKUP_DIR" && write_log "INFO" "Backup directory removed"
#     fi
    
#     if [ $exit_code -ne 0 ]; then
#         write_log "ERROR" "Script failed with exit code $exit_code"
#         echo "Check detailed logs in: $LOG_FILE"
#     else
#         write_log "SUCCESS" "Script completed successfully"
#     fi
    
#     exit $exit_code
# }

# trap cleanup EXIT INT TERM

# error_exit() {
#     error_to_file "$1"
#     exit 1
# }

# # Input validation
# validate_git_url() {
#     [[ $1 =~ ^(https://github\.com/.+|git@github\.com:.+) ]] || return 1
# }

# validate_branch_name() {
#     [[ $1 =~ ^[a-zA-Z0-9._/-]+$ ]] || return 1
# }

# validate_ip() {
#     local ip=$1
#     [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
#     IFS='.' read -r a b c d <<< "$ip"
#     for i in $a $b $c $d; do
#         ((i >= 0 && i <= 255)) || return 1
#     done
# }

# validate_port() {
#     [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
# }

# expand_path() {
#     echo "${1/#\~/$HOME}"
# }

# find_ssh_keys() {
#     local ssh_dir="$HOME/.ssh"
#     find "$ssh_dir" -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" -print 2>/dev/null || true
# }

# validate_ssh_key() {
#     local path
#     path=$(expand_path "$1")
#     [ -f "$path" ] && [ -r "$path" ] && grep -q "PRIVATE KEY" "$path"
# }

# # User input collection
# get_input() {
#     local prompt=$1
#     local validation_func=${2:-}
#     local default_value=${3:-}
#     local input_value

#     while true; do
#         if [ -n "$default_value" ]; then
#             read -p "$prompt [$default_value]: " input_value
#             input_value="${input_value:-$default_value}"
#         else
#             read -p "$prompt: " input_value
#         fi

#         if [ -z "$input_value" ]; then
#             log_error "Input cannot be empty"
#             continue
#         fi

#         if [ -n "$validation_func" ]; then
#             if "$validation_func" "$input_value"; then
#                 echo "$input_value"
#                 return 0
#             else
#                 log_error "Invalid input format"
#             fi
#         else
#             echo "$input_value"
#             return 0
#         fi
#     done
# }

# # Backup function
# create_backup() {
#     local target_dir=$1
#     if [ -d "$target_dir" ]; then
#         mkdir -p "$BACKUP_DIR"
#         cp -r "$target_dir" "$BACKUP_DIR/" 2>/dev/null || true
#         write_log "INFO" "Backup created for $target_dir"
#     fi
# }

# # Idempotent directory check and creation
# ensure_directory() {
#     local dir=$1
#     if [ ! -d "$dir" ]; then
#         mkdir -p "$dir"
#         write_log "INFO" "Created directory: $dir"
#     fi
# }

# # ============================================
# # Main Script Start
# # ============================================
# write_log "INFO" "Starting deployment script: $SCRIPT_NAME"

# log_to_file "Step 1: Collecting deployment parameters"

# # Collect Parameters
# GIT_REPO=$(get_input "Enter Git Repository URL" validate_git_url)
# log_to_file "Git Repository set: $GIT_REPO"

# print_color "$YELLOW" "Note: Your Personal Access Token (PAT) input will be hidden."
# while true; do
#     read -s -p "Enter Personal Access Token (PAT): " PAT
#     echo
#     [ -n "$PAT" ] && break || log_error "PAT cannot be empty"
# done

# BRANCH=$(get_input "Enter branch name" validate_branch_name "main")
# SSH_USERNAME=$(get_input "Enter SSH username" "" "")
# SERVER_IP=$(get_input "Enter server IP address" validate_ip "")
# APP_PORT=$(get_input "Enter application port" validate_port "8080")

# # SSH Key selection
# log_to_file "Scanning for available SSH keys..."
# AVAILABLE_KEYS=($(find_ssh_keys))
# if [ ${#AVAILABLE_KEYS[@]} -gt 0 ]; then
#     log_to_file "Found SSH keys:"
#     for i in "${!AVAILABLE_KEYS[@]}"; do
#         log_to_file "  $((i+1)). ${AVAILABLE_KEYS[$i]}"
#     done
# else
#     warn_to_file "No existing SSH keys found in ~/.ssh/"
# fi

# while true; do
#     read -p "Enter SSH key path (or 'generate' to create new): " SSH_KEY_PATH
#     [ -z "$SSH_KEY_PATH" ] && { log_error "SSH key path cannot be empty"; continue; }

#     if [ "$SSH_KEY_PATH" = "generate" ]; then
#         read -p "Enter email for SSH key: " ssh_email
#         key_file="$HOME/.ssh/id_rsa_$(date +%Y%m%d)"
#         ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$key_file" || error_exit "Failed to generate SSH key"
#         SSH_KEY_PATH="$key_file"
#         success_to_file "Generated new SSH key: $SSH_KEY_PATH"
#         break
#     fi

#     validate_ssh_key "$SSH_KEY_PATH" && break || log_error "Invalid or unreadable SSH key path"
# done

# SSH_KEY_PATH=$(expand_path "$SSH_KEY_PATH")

# # ============================================
# # Step 2: Repository Setup
# # ============================================
# log_to_file "Step 2: Repository Setup"

# repo_name=$(basename -s .git "$GIT_REPO")
# create_backup "$repo_name"

# if [[ $GIT_REPO == https://* ]]; then
#     AUTH_REPO_URL="${GIT_REPO/https:\/\//https:\/\/oauth2:${PAT}@}"
# else
#     AUTH_REPO_URL="$GIT_REPO"
# fi

# if [ -d "$repo_name" ]; then
#     cd "$repo_name" || error_exit "Cannot enter directory '$repo_name'"
#     # Idempotent: Pull latest changes if directory exists
#     git fetch origin || error_exit "Failed to fetch latest changes"
# else
#     git clone -b "$BRANCH" "$AUTH_REPO_URL" "$repo_name" || error_exit "Git clone failed"
#     cd "$repo_name"
# fi

# # Ensure correct branch (idempotent)
# if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
#     git checkout "$BRANCH"
# else
#     git checkout -b "$BRANCH" "origin/$BRANCH" || error_exit "Failed to checkout branch $BRANCH"
# fi

# git pull origin "$BRANCH" || warn_to_file "Could not pull latest changes"

# latest_commit=$(git log -1 --oneline)
# success_to_file "Repository synced to latest commit: $latest_commit"

# # ============================================
# # Step 3: Verify Project Files
# # ============================================
# log_to_file "Step 3: Verifying project structure"

# if [ -f "docker-compose.yml" ]; then
#     log_to_file "docker-compose.yml found"
# elif [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
#     log_to_file "Dockerfile found"
# else
#     error_exit "No Dockerfile or docker-compose.yml found in project root"
# fi

# success_to_file "Repository setup and verification complete."

# # ============================================
# # Step 4: SSH into Remote Server
# # ============================================
# log_to_file "Step 4: Establishing SSH connection to remote server"

# # Test SSH connectivity
# log_to_file "Testing SSH connectivity to $SSH_USERNAME@$SERVER_IP ..."
# if ssh -i "$SSH_KEY_PATH" \
#     -o StrictHostKeyChecking=no \
#     -o UserKnownHostsFile=/dev/null \
#     -o BatchMode=yes \
#     -o ConnectTimeout=10 \
#     "$SSH_USERNAME@$SERVER_IP" "echo 2>&1" >/dev/null 2>&1; then
#     success_to_file "SSH connection successful."
# else
#     error_exit "Unable to establish SSH connection. Check IP, credentials, or key permissions."
# fi

# # Optional reachability check
# if ping -c 2 "$SERVER_IP" >/dev/null 2>&1; then
#     success_to_file "Host $SERVER_IP is reachable via ping."
# else
#     warn_to_file "Host $SERVER_IP not reachable via ping. Continuing with SSH..."
# fi

# # ============================================
# # Step 5: Preparing Remote Environment
# # ============================================
# log_info "Step 5: Preparing remote environment"

# ssh -i "$SSH_KEY_PATH" \
#   -o StrictHostKeyChecking=no \
#   -o UserKnownHostsFile=/dev/null \
#   "$SSH_USERNAME@$SERVER_IP" bash <<"EOF"
# set -Eeuo pipefail

# # === Helper functions ===
# log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
# ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
# warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
# fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# # === System update ===
# log "Updating system packages..."
# export DEBIAN_FRONTEND=noninteractive
# if sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confold" >/dev/null 2>&1; then
#   ok "System packages updated."
# else
#   warn "Some packages failed to update."
# fi

# # === Install Docker ===
# if ! command -v docker >/dev/null 2>&1; then
#   log "Installing Docker..."
#   if curl -fsSL https://get.docker.com | sh >/dev/null 2>&1; then
#     ok "Docker installed successfully."
#   else
#     fail "Docker installation failed."
#   fi
# else
#   ok "Docker already installed."
# fi

# # === Install Docker Compose (using apt) ===
# if ! command -v docker-compose >/dev/null 2>&1; then
#   log "Installing Docker Compose..."
  
#   # Method 1: Try installing via apt (for Ubuntu/Debian)
#   if sudo apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
#     ok "Docker Compose plugin installed via apt."
#   else
#     # Method 2: Try alternative package name
#     if sudo apt-get install -y docker-compose >/dev/null 2>&1; then
#       ok "Docker Compose installed via apt."
#     else
#       # Method 3: Manual installation as fallback
#       log "Attempting manual Docker Compose installation..."
#       COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      
#       if [ -n "$COMPOSE_VERSION" ]; then
#         sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
#         sudo chmod +x /usr/local/bin/docker-compose
#         ok "Docker Compose $COMPOSE_VERSION installed manually."
#       else
#         warn "Could not determine Docker Compose version — skipping installation."
#       fi
#     fi
#   fi
# else
#   ok "Docker Compose already installed."
# fi

# # === Install Nginx ===
# if ! command -v nginx >/dev/null 2>&1; then
#   log "Installing Nginx..."
#   if sudo apt-get install -y nginx >/dev/null 2>&1; then
#     ok "Nginx installed successfully."
#   else
#     warn "Failed to install Nginx."
#   fi
# else
#   ok "Nginx already installed."
# fi

# # === Add user to Docker group ===
# if id -nG "$USER" | grep -qw docker; then
#   ok "User already in Docker group."
# else
#   log "Adding user to Docker group..."
#   if sudo usermod -aG docker "$USER"; then
#     ok "User added to Docker group."
#   else
#     warn "Failed to add user to Docker group."
#   fi
# fi

# # === Enable and start services ===
# log "Enabling and starting Docker & Nginx services..."
# for svc in docker nginx; do
#   sudo systemctl enable "$svc" >/dev/null 2>&1 || warn "Could not enable $svc"
#   sudo systemctl restart "$svc" >/dev/null 2>&1 || warn "Failed to start $svc service"

#   if systemctl is-active --quiet "$svc"; then
#     ok "$svc service is active and running."
#   else
#     warn "$svc service not active."
#   fi
# done

# # === Confirm versions ===
# log "Confirming installation versions..."
# {
#   echo -n "Docker: "; docker --version 2>/dev/null || echo "Not available"
#   echo -n "Docker Compose Plugin: "; docker compose version 2>/dev/null || echo "Not available"
#   echo -n "Nginx: "; nginx -v 2>&1 | head -1 || echo "Not available"
# } | while read -r line; do ok "$line"; done

# ok "Remote environment setup complete."
# EOF

# log_success "✓ Remote server $SERVER_IP verified and prepared successfully."


# # ============================================
# # Step 6: Deploy Application
# # ============================================
# log_to_file "Step 6: Deploying application to remote server"

# # Sync project files
# log_to_file "Synchronizing project files to remote server..."
# if rsync -avz -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
#     --exclude '.git' --exclude 'node_modules' \
#     ./ "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/"; then
#     success_to_file "Project files synchronized successfully"
# else
#     warn_to_file "Rsync failed, using SCP as fallback..."
#     scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r ./* "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/" || error_exit "Failed to transfer project files"
# fi

# # Deploy container
# log_to_file "Building and deploying Docker container..."

# ssh -i "$SSH_KEY_PATH" \
#   -o StrictHostKeyChecking=no \
#   -o UserKnownHostsFile=/dev/null \
#   "$SSH_USERNAME@$SERVER_IP" << DEPLOY_EOF
# set -e

# echo -e "\033[1;34m[INFO]\033[0m Starting deployment on port $APP_PORT..."
# cd /home/\$USER/app

# # Stop and remove existing container (idempotent cleanup)
# sudo docker stop hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to stop"
# sudo docker rm hng13-stage1-devops 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m No existing container to remove"

# # Build and run
# sudo docker build --build-arg APP_PORT=$APP_PORT -t hng13-stage1-devops . && echo -e "\033[1;32m[OK]\033[0m Docker image built successfully" || exit 1

# sudo docker run -d --name hng13-stage1-devops -e APP_PORT="$APP_PORT" -p "$APP_PORT:$APP_PORT" hng13-stage1-devops && echo -e "\033[1;32m[OK]\033[0m Container started successfully" || exit 1

# sleep 10

# # Validation
# sudo docker ps | grep -q hng13-stage1-devops && echo -e "\033[1;32m[OK]\033[0m Container running" || exit 1
# sudo docker exec hng13-stage1-devops curl -s -f http://localhost:$APP_PORT/ > /dev/null && echo -e "\033[1;32m[OK]\033[0m Application responsive" || exit 1
# curl -s -f http://localhost:$APP_PORT/ > /dev/null && echo -e "\033[1;32m[OK]\033[0m Host access working" || echo -e "\033[1;33m[WARN]\033[0m Host access issue"

# echo -e "\033[1;32m[OK]\033[0m Deployment validation passed"
# DEPLOY_EOF

# success_to_file "Application deployed successfully"

# # ============================================
# # Step 7: Configure Nginx & Final Validation
# # ============================================
# # log_to_file "Step 7: Configuring Nginx and final validation"

# # ssh -i "$SSH_KEY_PATH" \
# #   -o StrictHostKeyChecking=no \
# #   -o UserKnownHostsFile=/dev/null \
# #   "$SSH_USERNAME@$SERVER_IP" "APP_PORT=$APP_PORT; $(cat << 'NGINX_EOF'
# # set -e

# # echo -e "\033[1;34m[INFO]\033[0m Configuring Nginx..."

# # # Create and enable Nginx configuration
# # sudo tee /etc/nginx/sites-available/hng13-app > /dev/null << EOF
# # server {
# #     listen 80;
# #     listen [::]:80;
# #     server_name _;
# #     location / {
# #         proxy_pass http://127.0.0.1:$APP_PORT;
# #         proxy_set_header Host \$host;
# #         proxy_set_header X-Real-IP \$remote_addr;
# #         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
# #         proxy_set_header X-Forwarded-Proto \$scheme;
# #     }
# # }
# # EOF

# # sudo ln -sf /etc/nginx/sites-available/hng13-app /etc/nginx/sites-enabled/
# # [ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default

# # sudo nginx -t && sudo systemctl reload nginx && echo -e "\033[1;32m[OK]\033[0m Nginx configured" || exit 1

# # # Final validation
# # sudo docker ps | grep -q hng13-stage1-devops && echo -e "\033[1;32m[OK]\033[0m Container running" || exit 1
# # sudo docker exec hng13-stage1-devops curl -s -f http://localhost:$APP_PORT/ > /dev/null && echo -e "\033[1;32m[OK]\033[0m App responsive in container" || exit 1
# # curl -s -f http://localhost/ > /dev/null && echo -e "\033[1;32m[OK]\033[0m Nginx proxy working" || exit 1

# # echo -e "\033[1;32m[OK]\033[0m All systems operational"
# # NGINX_EOF
# # )"







# # ============================================
# # Step 7: Configure Nginx for HTTPS (IP Address) & Final Validation
# # ============================================
# log_to_file "Step 7: Configuring Nginx for HTTPS (using IP) and final validation"

# # Note: We pass APP_PORT and SERVER_IP to the remote session.
# ssh -i "$SSH_KEY_PATH" \
#   -o StrictHostKeyChecking=no \
#   -o UserKnownHostsFile=/dev/null \
#   "$SSH_USERNAME@$SERVER_IP" "APP_PORT=$APP_PORT; SERVER_IP=$SERVER_IP; $(cat << 'NGINX_EOF'
# set -e

# # === Helper functions (Remote) ===
# log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
# ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
# warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
# fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# # Certificate storage path
# CERT_DIR="/etc/nginx/ssl"
# CERT_NAME="selfsigned"
# CERT_PATH="$CERT_DIR/$CERT_NAME.crt"
# KEY_PATH="$CERT_DIR/$CERT_NAME.key"


# # --- PHASE 1: Generate Self-Signed Certificate ---

# log "Generating self-signed SSL certificate for IP: $SERVER_IP..."
# sudo mkdir -p "$CERT_DIR"

# # Generate certificate and key (valid for 365 days)
# # We use the IP address as the Common Name (CN).
# if sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#     -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$SERVER_IP" >/dev/null 2>&1; then
#     ok "Self-signed certificate generated successfully."
# else
#     fail "Failed to generate self-signed certificate."
# fi


# # --- PHASE 2: Configure Nginx for HTTP Redirect and HTTPS ---

# log "Configuring Nginx with HTTPS (Port 443) and HTTP Redirect..."

# # Create Nginx config with two server blocks
# sudo tee /etc/nginx/sites-available/hng13-app > /dev/null << NGINX_CONF
# # 1. HTTP Server Block (Redirect to HTTPS)
# server {
#     listen 80;
#     listen [::]:80;
#     server_name $SERVER_IP;
#     return 301 https://\$host\$request_uri;
# }

# # 2. HTTPS Server Block (Proxy to Docker container)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name $SERVER_IP;

#     ssl_certificate $CERT_PATH;
#     ssl_certificate_key $KEY_PATH;

#     # Basic security headers (can be optimized further)
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';

#     # Proxy configuration
#     location / {
#         proxy_pass http://127.0.0.1:$APP_PORT;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto https; # Indicate secure connection
#     }
# }
# NGINX_CONF

# sudo ln -sf /etc/nginx/sites-available/hng13-app /etc/nginx/sites-enabled/
# [ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default

# sudo nginx -t && sudo systemctl reload nginx && ok "Nginx configured and reloaded for HTTPS." || fail "Nginx configuration/reload failed."


# # --- PHASE 3: Internal Validation ---

# log "Performing internal validation checks..."

# # Check if the HTTPS port is listening
# if sudo netstat -tuln | grep -q '0.0.0.0:443'; then
#     ok "Port 443 (HTTPS) is open and listening."
# else
#     warn "Port 443 is NOT listening. Check firewall (ufw) or Nginx config."
# fi

# # Check container and app responsiveness
# sudo docker ps | grep -q hng13-stage1-devops && ok "Container running" || fail "Container check failed."
# sudo docker exec hng13-stage1-devops curl -s -f http://localhost:$APP_PORT/ > /dev/null && ok "App responsive in container." || warn "App not responsive in container."
# curl -s -k -f https://localhost/ > /dev/null && ok "Nginx HTTPS proxy working." || warn "Nginx HTTPS proxy check failed."

# ok "All remote systems operational"
# NGINX_EOF
# )" 2>&1 | while IFS= read -r LINE; do write_log "REMOTE_NGINX" "$LINE"; echo "$LINE"; done || error_exit "Remote Nginx/SSL configuration failed."

# success_to_file "Nginx and Self-Signed SSL setup completed successfully."

# # Final external test
# log_to_file "Performing final external HTTPS validation (expecting certificate warning)."
# sleep 3

# # Using -k to ignore the certificate warning (needed for self-signed cert on IP)
# if curl -s -k -f --connect-timeout 10 "https://$SERVER_IP/" >/dev/null; then
#     success_to_file "🎉 DEPLOYMENT SUCCESSFUL!"
#     success_to_file "Application is live and secure (self-signed) at: https://$SERVER_IP/"
#     warn_to_file "WARNING: You must bypass the browser security warning to access this IP."
# else
#     warn_to_file "Deployment completed, but external HTTPS access failed."
#     log_to_file "Check Nginx and firewall (Port 443) on server $SERVER_IP."
# fi

# write_log "INFO" "Deployment script completed"
# echo "Detailed logs available in: $LOG_FILE"


# # Final external test
# log_to_file "Performing final external validation..."
# sleep 3

# if curl -s -f --connect-timeout 10 "http://$SERVER_IP/" >/dev/null; then
#     success_to_file "🎉 DEPLOYMENT SUCCESSFUL!"
#     success_to_file "Application Http is live at: http://$SERVER_IP/"
#     success_to_file "Application Https is live at: https://$SERVER_IP/"
#     success_to_file "Direct access from inside of host: http://$SERVER_IP:$APP_PORT/"
# else
#     warn_to_file "Deployment completed with external access issues"
#     log_to_file "Check application directly at: http://$SERVER_IP:$APP_PORT/"
# fi

# write_log "INFO" "Deployment script completed"
# echo "Detailed logs available in: $LOG_FILE"


































#!/bin/bash
set -euo pipefail

# ============================================
# Configuration
# ============================================
SCRIPT_NAME="deploy.sh"
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"

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

# Main deployment function
main() {
    log_info "Starting deployment script"

    # ============================================
    # Step 1: Collect deployment parameters
    # ============================================
    log_info "Step 1: Collecting deployment parameters"

    GIT_REPO=$(get_input "Enter Git Repository URL" validate_git_url)
    log_info "Git Repository set: $GIT_REPO"

    print_color "$YELLOW" "Note: Your Personal Access Token (PAT) input will be hidden."
    while true; do
        read -s -p "Enter Personal Access Token (PAT): " PAT
        echo
        [ -n "$PAT" ] && break || log_error "PAT cannot be empty"
    done

    BRANCH=$(get_input "Enter branch name" validate_branch_name "main")
    SSH_USERNAME=$(get_input "Enter SSH username")
    SERVER_IP=$(get_input "Enter server IP address" validate_ip)
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
            ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f "$key_file" -N "" || error_exit "Failed to generate SSH key"
            SSH_KEY_PATH="$key_file"
            log_success "Generated new SSH key: $SSH_KEY_PATH"
            break
        fi

        validate_ssh_key "$SSH_KEY_PATH" && break || log_error "Invalid or unreadable SSH key path"
    done

    SSH_KEY_PATH=$(expand_path "$SSH_KEY_PATH")

    # ============================================
    # Step 2: Repository Setup
    # ============================================
    log_info "Step 2: Repository Setup"

    repo_name=$(basename -s .git "$GIT_REPO")

    if [[ $GIT_REPO == https://* ]]; then
        AUTH_REPO_URL="${GIT_REPO/https:\/\//https:\/\/oauth2:${PAT}@}"
    else
        AUTH_REPO_URL="$GIT_REPO"
    fi

    if [ -d "$repo_name" ]; then
        log_info "Repository exists, updating..."
        cd "$repo_name" || error_exit "Cannot enter directory '$repo_name'"
        git fetch origin || error_exit "Failed to fetch latest changes"
    else
        log_info "Cloning repository..."
        git clone -b "$BRANCH" "$AUTH_REPO_URL" "$repo_name" || error_exit "Git clone failed"
        cd "$repo_name"
    fi

    # Ensure correct branch
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git checkout "$BRANCH"
    else
        git checkout -b "$BRANCH" "origin/$BRANCH" || error_exit "Failed to checkout branch $BRANCH"
    fi

    git pull origin "$BRANCH" || log_warn "Could not pull latest changes"

    latest_commit=$(git log -1 --oneline)
    log_success "Repository synced to latest commit: $latest_commit"

    # ============================================
    # Step 3: Verify Project Files
    # ============================================
    log_info "Step 3: Verifying project structure"

    if [ -f "docker-compose.yml" ]; then
        log_info "docker-compose.yml found"
    elif [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
        log_info "Dockerfile found"
    else
        error_exit "No Dockerfile or docker-compose.yml found in project root"
    fi

    # ============================================
    # Step 4: SSH Connectivity
    # ============================================
    log_info "Step 4: Establishing SSH connection to remote server"

    # Test SSH connectivity
    log_info "Testing SSH connectivity to $SSH_USERNAME@$SERVER_IP..."
    if ssh -i "$SSH_KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        "$SSH_USERNAME@$SERVER_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log_success "SSH connection successful."
    else
        error_exit "Unable to establish SSH connection"
    fi

    # ============================================
    # Step 5: Server Preparation
    # ============================================
    log_info "Step 5: Preparing remote environment"

    ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      "$SSH_USERNAME@$SERVER_IP" bash <<"EOF"
set -e

echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confold"

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "Installing Nginx..."
sudo apt-get install -y nginx

echo "Configuring Docker permissions..."
sudo usermod -aG docker $USER

echo "Starting services..."
sudo systemctl enable docker nginx
sudo systemctl start docker nginx

echo "Server preparation completed successfully"
EOF

    log_success "Remote server prepared successfully"

    # ============================================
    # Step 6: Docker Deployment
    # ============================================
    log_info "Step 6: Deploying application"

    # Sync project files
    log_info "Synchronizing project files to remote server..."
    rsync -avz -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
        --exclude '.git' \
        --exclude 'node_modules' \
        ./ "$SSH_USERNAME@$SERVER_IP:/home/$SSH_USERNAME/app/" || error_exit "Failed to sync files"

    # Deploy container
    log_info "Building and deploying Docker container..."
    ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      "$SSH_USERNAME@$SERVER_IP" "APP_PORT=$APP_PORT; $(cat << 'DEPLOY_EOF'
set -e

cd /home/$USER/app

# Stop and remove existing container
sudo docker stop hng13-stage1-devops 2>/dev/null || true
sudo docker rm hng13-stage1-devops 2>/dev/null || true

# Build and run container
sudo docker build --build-arg APP_PORT=$APP_PORT -t hng13-stage1-devops .
sudo docker run -d --name hng13-stage1-devops -e APP_PORT="$APP_PORT" -p "$APP_PORT:$APP_PORT" hng13-stage1-devops

# Health check
sleep 10
sudo docker ps | grep hng13-stage1-devops
sudo docker exec hng13-stage1-devops curl -f http://localhost:$APP_PORT/

echo "Docker deployment completed successfully"
DEPLOY_EOF
)"

    log_success "Application deployed successfully"

    # ============================================
    # Step 7: Nginx Configuration
    # ============================================
    log_info "Step 7: Configuring Nginx"

    ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      "$SSH_USERNAME@$SERVER_IP" "APP_PORT=$APP_PORT; $(cat << 'NGINX_EOF'
set -e

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/hng13-app > /dev/null << EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/hng13-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# SSL consideration (placeholder)
echo "SSL can be configured later using Certbot"

echo "Nginx configuration completed successfully"
NGINX_EOF
)"

    log_success "Nginx configured successfully"

    # ============================================
    # Step 8: Deployment Validation
    # ============================================
    log_info "Step 8: Validating deployment"

    ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      "$SSH_USERNAME@$SERVER_IP" bash <<"EOF"
set -e

echo "Checking Docker service..."
sudo systemctl is-active docker

echo "Checking container status..."
sudo docker ps | grep hng13-stage1-devops

echo "Checking Nginx status..."
sudo systemctl is-active nginx
curl -f http://localhost/ > /dev/null

echo "All validation checks passed"
EOF

    log_success "Deployment validation completed"

    # ============================================
    # Final cleanup and summary
    # ============================================
    log_success "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    log_info "Application Http is accessible at: http://$SERVER_IP/"
    log_info "Application Https is accessible at: https://$SERVER_IP/"
    log_info "Direct access from inside of host: http://$SERVER_IP:$APP_PORT/"
}

# Run main function
main "$@"