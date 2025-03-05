#!/bin/bash

# Default inventory file path
INVENTORY_FILE="inventory.yml"
PLAYBOOK_FILE="playbook.yml"  # Adjust this to your actual playbook filename

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to detect Linux distribution and install yq from main repos
install_yq() {
    if command -v yq &> /dev/null; then
        echo "yq is already installed"
        return 0
    fi

    echo "yq is not installed. Attempting to install from package manager..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                echo "Detected Debian/Ubuntu-based system"
                sudo apt-get update
                sudo apt-get install -y yq
                ;;
            centos|rhel)
                echo "Detected RHEL/CentOS-based system"
                sudo yum install -y epel-release
                sudo yum install -y yq
                ;;
            fedora)
                echo "Detected Fedora-based system"
                sudo dnf install -y yq
                ;;
            arch|manjaro)
                echo "Detected Arch-based system"
                sudo pacman -Syu --noconfirm
                sudo pacman -S --noconfirm yq
                ;;
            *)
                echo -e "${RED}Unsupported distribution: $ID${NC}"
                echo "Please install yq manually from your package manager or https://github.com/kislyuk/yq"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}Cannot determine Linux distribution${NC}"
        echo "Please install yq manually from your package manager"
        exit 1
    fi

    if ! command -v yq &> /dev/null; then
        echo -e "${RED}Failed to install yq${NC}"
        echo "Please ensure your package manager is configured correctly and try again"
        exit 1
    fi
    echo -e "${GREEN}yq installed successfully${NC}"
}

# Function to install Python and bcrypt
install_bcrypt() {
    if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Attempting to install..."
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y python3 python3-pip
                    ;;
                centos|rhel|fedora)
                    sudo yum install -y python3 python3-pip
                    ;;
                arch|manjaro)
                    sudo pacman -Syu --noconfirm
                    sudo pacman -S --noconfirm python python-pip
                    ;;
                *)
                    echo -e "${RED}Unsupported distribution for Python installation: $ID${NC}"
                    exit 1
                    ;;
            esac
        fi
    fi

    if ! python3 -c "import bcrypt" &> /dev/null; then
        echo "bcrypt module not found. Installing via pip..."
        sudo pip3 install bcrypt
    fi

    if ! python3 -c "import bcrypt" &> /dev/null; then
        echo -e "${RED}Failed to install bcrypt${NC}"
        exit 1
    fi
    echo "Python and bcrypt are ready"
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    eval $var_name="${input:-$default}"
}

# Function to prompt for password with validation
prompt_for_password() {
    local var_name="$1"
    local password=""
    
    while true; do
        read -s -p "Enter password (min 8 characters): " password
        echo
        if [ -z "$password" ]; then
            echo -e "${RED}Password cannot be empty${NC}"
        elif [ ${#password} -lt 8 ]; then
            echo -e "${RED}Password must be at least 8 characters${NC}"
        else
            break
        fi
    done
    eval $var_name="$password"
}

# Function to generate bcrypt hash
generate_bcrypt_hash() {
    local password="$1"
    python3 -c "import bcrypt; print(bcrypt.hashpw('$password'.encode('utf-8'), bcrypt.gensalt()).decode('utf-8'))"
}

# Main script
echo "Ansible GitLab Runner Configuration Script"
echo "========================================"

# Install yq if not present
install_yq

# Install Python and bcrypt
install_bcrypt

# Ask for number of runners
prompt_with_default "How many runners do you want to configure" "1" "num_runners"

# Validate number of runners
if ! [[ "$num_runners" =~ ^[0-9]+$ ]] || [ "$num_runners" -lt 1 ]; then
    echo -e "${RED}Error: Please enter a valid number greater than 0${NC}"
    exit 1
fi

# Array to store runner configurations
declare -A runners_config

# Loop through each runner
for ((i=1; i<=num_runners; i++)); do
    echo -e "\nConfiguring Runner #$i"
    echo "--------------------"
    
    # Prompt for variables with defaults
    prompt_with_default "Enter runner name" "runner$i" "runner_name"
    prompt_with_default "Enter Ansible host IP" "10.10.34.$((35+i))" "ansible_host"
    prompt_with_default "Enter SSH private key path" "~/.ssh/ssh-key" "ssh_key"
    prompt_with_default "Enter Ansible port" "22" "ansible_port"
    prompt_with_default "Enter GitLab URL" "https://gitlab.name.tld" "gitlab_url"
    prompt_with_default "Enter GitLab Runner token" "gl" "runner_token"
    prompt_with_default "Enter runner tags (comma-separated)" "docker,linux" "runner_tags"
    prompt_with_default "Enter runner network" "runner-net" "runner_network"
    prompt_with_default "Enter concurrent jobs" "5" "concurrent"
    prompt_with_default "Enter check interval" "2" "interval"
    prompt_with_default "Enter shutdown timeout" "10" "shutdown_timeout"
    prompt_with_default "Enter metrics username" "admin" "metrics_user"
    prompt_for_password "metrics_pass"
    hashed_metrics_pass=$(generate_bcrypt_hash "$metrics_pass")
    prompt_with_default "Enter Traefik subdomain" "traefik" "traefik_sub"
    prompt_with_default "Enter domain" "example.runner.gitlab.name.tld" "domain"
    prompt_with_default "Enter metrics subdomain" "metrics.runner.gitlab.com" "metrics_sub"
    prompt_with_default "Enter Traefik metrics subdomain" "trmetrics.runner.gitlab.com" "traefik_metrics_sub"
    
    # Prompt for basic auth username and password
    prompt_with_default "Enter basic auth username" "admin" "basic_auth_user"
    prompt_for_password "basic_auth_pass"
    hashed_pass=$(generate_bcrypt_hash "$basic_auth_pass")

    # Store configuration
    runners_config["$runner_name"]=$(cat <<EOF
ansible_host: "$ansible_host"
ansible_ssh_private_key_file: "$ssh_key"
ansible_port: $ansible_port
gitlab_url: "$gitlab_url"
gitlab_runner_token: "$runner_token"
gitlab_runner_tags: "$runner_tags"
gitlab_runner_network: "$runner_network"
runner_concurrent: "$concurrent"
runner_interval: "$interval"
runner_shutdown_timeout: "$shutdown_timeout"
metrics_username: "$metrics_user"
metrics_password: "$hashed_metrics_pass"
traefik_subdomain: "$traefik_sub"
domain: "$domain"
metrics_subdomain: "$metrics_sub"
traefik_metrics_subdomain: "$traefik_metrics_sub"
basic_auth_users:
  $basic_auth_user: "$hashed_pass"
EOF
)
done

# Confirm before proceeding
echo -e "\n${GREEN}Review your configurations:${NC}"
for runner_name in "${!runners_config[@]}"; do
    echo "Runner: $runner_name"
    host_ip=$(echo "${runners_config[$runner_name]}" | grep -oP '(?<=ansible_host: ")[^"]*')
    gitlab_url=$(echo "${runners_config[$runner_name]}" | grep -oP '(?<=gitlab_url: ")[^"]*')
    runner_token=$(echo "${runners_config[$runner_name]}" | grep -oP '(?<=gitlab_runner_token: ")[^"]*')
    basic_auth_user=$(echo "${runners_config[$runner_name]}" | grep -oP '(?<=basic_auth_users:\n  )[^:]*')
    echo "Host IP: $host_ip"
    echo "GitLab URL: $gitlab_url"
    echo "Runner token: $runner_token"
    echo "Basic Auth User: $basic_auth_user"
    echo "------------------------"
done

read -p "Proceed with these values? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Aborted by user"
    exit 0
fi

# Create new inventory file
echo "Generating new inventory file..."
cat > "$INVENTORY_FILE" <<EOF
---
all:
  children:
    gitlab_runners:
      hosts:
EOF

# Add each runner to the inventory
for runner_name in "${!runners_config[@]}"; do
    echo "        $runner_name:" >> "$INVENTORY_FILE"
    echo "${runners_config[$runner_name]}" | sed 's/^/          /' >> "$INVENTORY_FILE"
done

# Verify the file exists and is not empty
if [ -s "$INVENTORY_FILE" ]; then
    echo -e "${GREEN}Inventory file generated successfully${NC}"
    cat "$INVENTORY_FILE"  # Show the generated file for verification
else
    echo -e "${RED}Failed to generate inventory file${NC}"
    exit 1
fi

# Run Ansible playbook
echo -e "\nRunning Ansible playbook..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Playbook executed successfully${NC}"
else
    echo -e "${RED}Playbook execution failed${NC}"
    exit 1
fi
