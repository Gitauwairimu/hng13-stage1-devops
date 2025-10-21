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
ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$SSH_USERNAME@$SERVER_IP" \
  "APP_PORT=$APP_PORT bash -s" <<'EOF'
set -Eeuo pipefail

log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
fail()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

DEPLOY_DIR="/home/$USER/app"
PROJECT_NAME=$(basename "$DEPLOY_DIR")

log "Checking deployed files in $DEPLOY_DIR..."
if [ ! -d "$DEPLOY_DIR" ]; then
  fail "Project directory $DEPLOY_DIR not found on remote server"
fi

cd "$DEPLOY_DIR" || fail "Cannot enter project directory $DEPLOY_DIR"

log "Remote Docker files:"
ls -la | grep -iE "(dockerfile|docker-compose)" || warn "No Docker files found"

log "Stopping any existing container..."
sudo docker stop "$PROJECT_NAME" 2>/dev/null || warn "No container to stop"
sudo docker rm "$PROJECT_NAME" 2>/dev/null || warn "No container to remove"

log "Building Docker image..."
if sudo docker build -t "$PROJECT_NAME" .; then
  ok "Docker image built successfully"
else
  fail "Docker build failed"
fi

log "Running container (internal port only, $APP_PORT)..."
sudo docker run -d --name "$PROJECT_NAME" "$PROJECT_NAME"

sleep 5

log "Checking if app responds internally..."
if sudo docker exec "$PROJECT_NAME" curl -sf http://localhost:$APP_PORT; then
  ok "✅ App is accessible internally on port $APP_PORT"
else
  fail "❌ App not reachable on $APP_PORT inside container"
fi

log "Checking container logs for confirmation..."
sudo docker logs "$PROJECT_NAME" | tail -20

ok "Deployment completed successfully!"
EOF
