#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate Git repository URL
validate_git_url() {
    local url=$1
    if [[ $url =~ ^https://github.com/.+ ]] || [[ $url =~ ^git@github.com:.+ ]]; then
        return 0
    else
        print_color $RED "Error: Invalid Git repository URL format"
        return 1
    fi
}

# Function to validate branch name
validate_branch_name() {
    local branch=$1
    if [[ $branch =~ ^[a-zA-Z0-9/._-]+$ ]]; then
        return 0
    else
        print_color $RED "Error: Invalid branch name"
        return 1
    fi
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local IFS='.'
        read -r i1 i2 i3 i4 <<< "$ip"
        if [[ $i1 -le 255 && $i2 -le 255 && $i3 -le 255 && $i4 -le 255 ]]; then
            return 0
        fi
    fi
    print_color $RED "Error: Invalid IP address format"
    return 1
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        print_color $RED "Error: Port must be a number between 1 and 65535"
        return 1
    fi
}

# Function to expand tilde in paths
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# Function to find available SSH keys
find_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    local keys=()
    
    if [ -d "$ssh_dir" ]; then
        while IFS= read -r -d '' file; do
            # Exclude .pub files (public keys), known_hosts, and config
            if [[ ! $file =~ \.pub$ ]] && [[ ! $file =~ known_hosts$ ]] && [[ ! $file =~ config$ ]]; then
                # Check if it's a regular file and readable
                if [ -f "$file" ] && [ -r "$file" ]; then
                    # Basic check if it might be a private key
                    if head -n 1 "$file" | grep -q "PRIVATE KEY" || [ $(stat -c%s "$file") -gt 100 ]; then
                        keys+=("$file")
                    fi
                fi
            fi
        done < <(find "$ssh_dir" -type f -print0 2>/dev/null)
    fi
    
    printf '%s\n' "${keys[@]}"
}

# Function to validate SSH key path
validate_ssh_key() {
    local key_path=$1
    local expanded_path
    
    # Expand tilde to absolute path
    expanded_path=$(expand_path "$key_path")
    
    if [ -f "$expanded_path" ] && [ -r "$expanded_path" ]; then
        # Basic check if it looks like a private key
        if head -n 1 "$expanded_path" | grep -q "PRIVATE KEY" || [ $(stat -c%s "$expanded_path") -gt 100 ]; then
            return 0
        else
            print_color $YELLOW "Warning: File exists but may not be a valid SSH private key"
            read -p "Do you want to use this file anyway? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        fi
    else
        print_color $RED "Error: SSH key file not found or not readable: $expanded_path"
        
        # Show available SSH keys
        local available_keys=($(find_ssh_keys))
        if [ ${#available_keys[@]} -gt 0 ]; then
            print_color $YELLOW "Available SSH keys in your system:"
            for key in "${available_keys[@]}"; do
                print_color $YELLOW "  - $key"
            done
        else
            print_color $YELLOW "No SSH keys found in ~/.ssh/"
            print_color $YELLOW "You may need to generate an SSH key with: ssh-keygen -t rsa -b 4096"
        fi
        
        return 1
    fi
}

# Function to get user input with validation
get_input() {
    local prompt=$1
    local validation_func=$2
    local default_value=$3
    local input_value=""
    
    while true; do
        if [ -n "$default_value" ]; then
            read -p "$prompt [$default_value]: " input_value
            if [ -z "$input_value" ]; then
                input_value="$default_value"
                echo "$input_value"
                return
            fi
        else
            read -p "$prompt: " input_value
        fi
        
        if [ -z "$input_value" ]; then
            print_color $RED "Error: Input cannot be empty"
            continue
        fi
        
        if [ -n "$validation_func" ]; then
            if $validation_func "$input_value"; then
                break
            fi
        else
            break
        fi
    done
    
    echo "$input_value"
}

# Main script
echo "================================================"
print_color $BLUE "Git Deployment Configuration Setup"
echo "================================================"
echo ""

# Git Repository URL
GIT_REPO=$(get_input "Enter Git Repository URL" validate_git_url)

# Personal Access Token
print_color $YELLOW "Note: PAT will be masked during input"
while true; do
    read -s -p "Enter Personal Access Token: " PAT
    echo
    if [ -n "$PAT" ]; then
        break
    else
        print_color $RED "Error: Personal Access Token cannot be empty"
    fi
done

# Branch name (optional, defaults to main)
BRANCH=$(get_input "Enter branch name" validate_branch_name "main")

# Remote server details
echo ""
print_color $BLUE "Remote Server Configuration"
echo "----------------------------------------"

# SSH Username
SSH_USERNAME=$(get_input "Enter SSH username")

# Server IP address
SERVER_IP=$(get_input "Enter server IP address" validate_ip)

# SSH key path with better guidance
echo ""
print_color $YELLOW "Looking for available SSH keys..."
AVAILABLE_KEYS=($(find_ssh_keys))

if [ ${#AVAILABLE_KEYS[@]} -gt 0 ]; then
    print_color $GREEN "Found these SSH keys:"
    for i in "${!AVAILABLE_KEYS[@]}"; do
        print_color $GREEN "  $((i+1)). ${AVAILABLE_KEYS[$i]}"
    done
    echo ""
    print_color $YELLOW "You can:"
    print_color $YELLOW "  1. Enter one of the paths above"
    print_color $YELLOW "  2. Enter a custom path"
    print_color $YELLOW "  3. Enter 'generate' to create a new SSH key"
    echo ""
fi

while true; do
    read -p "Enter SSH key path (or 'generate' to create new): " SSH_KEY_PATH
    
    if [ -z "$SSH_KEY_PATH" ]; then
        print_color $RED "Error: SSH key path cannot be empty"
        continue
    fi
    
    if [ "$SSH_KEY_PATH" = "generate" ]; then
        print_color $BLUE "Generating new SSH key..."
        read -p "Enter email for SSH key: " ssh_email
        ssh-keygen -t rsa -b 4096 -C "$ssh_email" -f ~/.ssh/id_rsa_$(date +%Y%m%d)
        SSH_KEY_PATH="$HOME/.ssh/id_rsa_$(date +%Y%m%d)"
        print_color $GREEN "Generated new SSH key: $SSH_KEY_PATH"
        break
    fi
    
    if validate_ssh_key "$SSH_KEY_PATH"; then
        break
    fi
done

# Expand the SSH key path for actual use
EXPANDED_SSH_KEY_PATH=$(expand_path "$SSH_KEY_PATH")

# Application port
APP_PORT=$(get_input "Enter application port" validate_port "8080")

# Display summary
echo ""
echo "================================================"
print_color $GREEN "Configuration Summary"
echo "================================================"
print_color $GREEN "Git Repository: $GIT_REPO"
print_color $GREEN "Branch: $BRANCH"
print_color $GREEN "SSH Username: $SSH_USERNAME"
print_color $GREEN "Server IP: $SERVER_IP"
print_color $GREEN "SSH Key Path: $SSH_KEY_PATH"
print_color $GREEN "Application Port: $APP_PORT"
print_color $GREEN "PAT: **********"
echo ""

# Confirmation
read -p "Proceed with these settings? (y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    print_color $GREEN "Configuration accepted!"
    
    # Export variables
    export GIT_REPO
    export PAT
    export BRANCH
    export SSH_USERNAME
    export SERVER_IP
    export SSH_KEY_PATH="$EXPANDED_SSH_KEY_PATH"
    export APP_PORT
    
    echo ""
    print_color $BLUE "Variables set and ready for use in deployment scripts"
else
    print_color $YELLOW "Configuration cancelled by user"
    exit 1
fi































# Function to clone or update repository
clone_or_update_repo() {
    local repo_url="$1"
    local pat="$2"
    local branch="$3"
    local repo_name=$(basename "$repo_url" .git)
    
    print_color $BLUE "Step 2: Repository Setup"
    echo "----------------------------------------"
    
    # Extract repo name from URL for directory
    if [[ $repo_url =~ https://.*github.com/(.*)/(.*)\.git ]]; then
        repo_name="${BASH_REMATCH[2]}"
    elif [[ $repo_url =~ https://.*github.com/(.*)/(.*) ]]; then
        repo_name="${BASH_REMATCH[2]}"
    fi
    
    # Create authenticated URL with PAT
    local auth_repo_url
    if [[ $repo_url == https://* ]]; then
        # Insert PAT after https://
        auth_repo_url="${repo_url/https:\/\//https://oauth2:${pat}@}"
    else
        auth_repo_url="$repo_url"
    fi
    
    # Check if repository directory already exists
    if [ -d "$repo_name" ]; then
        print_color $YELLOW "Repository directory '$repo_name' already exists. Pulling latest changes..."
        
        cd "$repo_name" || {
            print_color $RED "Error: Cannot enter repository directory '$repo_name'"
            return 1
        }
        
        # Stash any local changes to avoid conflicts
        if git diff --quiet && git diff --staged --quiet; then
            print_color $BLUE "No local changes detected"
        else
            print_color $YELLOW "Stashing local changes..."
            git stash push -m "Auto-stash by deployment script"
        fi
        
        # Pull latest changes
        print_color $BLUE "Pulling latest changes from remote..."
        if git pull "$auth_repo_url" "$branch"; then
            print_color $GREEN "Successfully pulled latest changes"
        else
            print_color $RED "Error: Failed to pull latest changes"
            cd ..
            return 1
        fi
        
    else
        print_color $BLUE "Cloning repository '$repo_name'..."
        
        if git clone -b "$branch" "$auth_repo_url" "$repo_name"; then
            print_color $GREEN "Successfully cloned repository"
            cd "$repo_name" || {
                print_color $RED "Error: Cannot enter repository directory '$repo_name'"
                return 1
            }
        else
            print_color $RED "Error: Failed to clone repository"
            return 1
        fi
    fi
    
    # Switch to specified branch (in case it wasn't specified in clone or pull)
    print_color $BLUE "Ensuring we're on branch '$branch'..."
    
    # Check if branch exists locally
    if git show-ref --quiet --verify "refs/heads/$branch"; then
        git checkout "$branch"
    else
        # Check if branch exists remotely
        if git ls-remote --exit-code --heads "$auth_repo_url" "$branch" >/dev/null; then
            git checkout -b "$branch" "origin/$branch"
        else
            print_color $RED "Error: Branch '$branch' does not exist in remote repository"
            cd ..
            return 1
        fi
    fi
    
    # Verify we're on the correct branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" = "$branch" ]; then
        print_color $GREEN "Successfully switched to branch: $branch"
    else
        print_color $RED "Error: Failed to switch to branch '$branch'. Current branch: $current_branch"
        cd ..
        return 1
    fi
    
    # Get the latest commit info
    latest_commit=$(git log -1 --oneline)
    print_color $GREEN "Latest commit: $latest_commit"
    
    cd ..
    return 0
}

# After the confirmation section in main script, add:
if [[ $confirm =~ ^[Yy]$ ]]; then
    print_color $GREEN "Configuration accepted!"
    
    # Create a temporary directory for the deployment
    DEPLOYMENT_DIR="deployment_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DEPLOYMENT_DIR"
    cd "$DEPLOYMENT_DIR" || {
        print_color $RED "Error: Cannot create deployment directory"
        exit 1
    }
    
    print_color $GREEN "Created deployment directory: $DEPLOYMENT_DIR"
    
    # Step 2: Clone/Update repository
    if clone_or_update_repo "$GIT_REPO" "$PAT" "$BRANCH"; then
        print_color $GREEN "✓ Repository setup completed successfully"
        
        # Export variables for use in other scripts
        export GIT_REPO
        export PAT
        export BRANCH
        export SSH_USERNAME
        export SERVER_IP
        export SSH_KEY_PATH="$EXPANDED_SSH_KEY_PATH"
        export APP_PORT
        export DEPLOYMENT_DIR
        
        echo ""
        print_color $BLUE "Current directory: $(pwd)"
        print_color $BLUE "Repository ready for deployment"
        
    else
        print_color $RED "✗ Repository setup failed"
        cd ..
        rm -rf "$DEPLOYMENT_DIR"
        exit 1
    fi
    
else
    print_color $YELLOW "Configuration cancelled by user"
    exit 1
fi





















    # Step 2: Clone/Update repository
    if clone_or_update_repo "$GIT_REPO" "$PAT" "$BRANCH"; then
        print_color $GREEN "✓ Repository setup completed successfully"
        
        # Step 3: Navigate and verify Docker files
        if navigate_and_verify_docker "$GIT_REPO"; then
            print_color $GREEN "✓ Project verification completed successfully"
            
            # Export variables for use in other scripts
            export GIT_REPO
            export PAT
            export BRANCH
            export SSH_USERNAME
            export SERVER_IP
            export SSH_KEY_PATH="$EXPANDED_SSH_KEY_PATH"
            export APP_PORT
            export DEPLOYMENT_DIR
            export PROJECT_DIR="$(pwd)"
            
            echo ""
            print_color $BLUE "Current directory: $(pwd)"
            print_color $BLUE "Project ready for Docker deployment"
            
        else
            print_color $RED "✗ Project verification failed - missing Docker configuration"
            cd ../..
            rm -rf "$DEPLOYMENT_DIR"
            exit 1
        fi
        
    else
        print_color $RED "✗ Repository setup failed"
        cd ..
        rm -rf "$DEPLOYMENT_DIR"
        exit 1
    fi