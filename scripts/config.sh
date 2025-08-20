#!/bin/bash

# Configuration management for the GKE Demo project
# This script handles dynamic project ID generation and persistence

CONFIG_FILE=".project-config"

# Function to generate a unique project ID
generate_project_id() {
    # GCP project ID rules:
    # - Must be 6-30 characters
    # - Can only contain lowercase letters, numbers, and hyphens
    # - Must start with a letter
    # - Cannot end with a hyphen
    # - Cannot contain consecutive hyphens
    
    local timestamp=$(date +%s)
    local random_suffix=$(printf "%04d" $((RANDOM % 10000)))
    local project_id="gke-demo-${timestamp}-${random_suffix}"
    
    # Ensure it's lowercase and follows GCP rules
    project_id=$(echo "$project_id" | tr '[:upper:]' '[:lower:]')
    
    # Ensure it doesn't exceed 30 characters
    if [ ${#project_id} -gt 30 ]; then
        # Truncate timestamp if needed
        local max_timestamp_length=$((30 - ${#random_suffix} - 9))  # 9 for "gke-demo--"
        local truncated_timestamp=${timestamp:0:$max_timestamp_length}
        project_id="gke-demo-${truncated_timestamp}-${random_suffix}"
    fi
    
    echo "$project_id"
}

# Function to get or create project ID
get_project_id() {
    if [ -f "$CONFIG_FILE" ]; then
        # Read existing project ID
        PROJECT_ID=$(cat "$CONFIG_FILE")
        echo "$PROJECT_ID"
    else
        # Generate new project ID
        PROJECT_ID=$(generate_project_id)
        echo "$PROJECT_ID" > "$CONFIG_FILE"
        echo "$PROJECT_ID"
    fi
}

# Function to prompt user for project ID
prompt_project_id() {
    echo "🔧 GKE Demo Project Configuration"
    echo "=================================="
    echo ""
    echo "GCP Project ID Requirements:"
    echo "• 6-30 characters"
    echo "• Lowercase letters, numbers, and hyphens only"
    echo "• Must start with a letter"
    echo "• Cannot end with a hyphen"
    echo "• Cannot contain consecutive hyphens"
    echo "• Must be globally unique across all GCP projects"
    echo ""
    echo "You can either:"
    echo "1. Use an existing GCP project ID"
    echo "2. Generate a new unique project ID"
    echo ""
    
    read -p "Enter your choice (1 or 2): " choice
    
    case $choice in
        1)
            read -p "Enter your GCP project ID: " PROJECT_ID
            if [ -z "$PROJECT_ID" ]; then
                echo "❌ Project ID cannot be empty. Generating a unique one instead."
                PROJECT_ID=$(generate_project_id)
            elif ! validate_project_id "$PROJECT_ID"; then
                echo "❌ Invalid project ID format. Generating a valid one instead."
                PROJECT_ID=$(generate_project_id)
            fi
            ;;
        2)
            PROJECT_ID=$(generate_project_id)
            echo "✅ Generated unique project ID: $PROJECT_ID"
            ;;
        *)
            echo "❌ Invalid choice. Generating a unique project ID."
            PROJECT_ID=$(generate_project_id)
            ;;
    esac
    
    # Save the project ID
    echo "$PROJECT_ID" > "$CONFIG_FILE"
    echo "$PROJECT_ID"
}

# Function to clear project ID (for teardown)
clear_project_id() {
    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
    fi
}

# Function to validate project ID format
validate_project_id() {
    local project_id=$1
    
    # Check if project ID follows GCP naming rules
    if [[ $project_id =~ ^[a-z][a-z0-9-]{5,29}$ ]] && \
       [[ ! $project_id =~ -- ]] && \
       [[ ! $project_id =~ -$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if project ID is available
check_project_id_availability() {
    local project_id=$1
    
    # Check if project already exists
    if gcloud projects describe "$project_id" >/dev/null 2>&1; then
        return 1  # Project exists
    else
        return 0  # Project is available
    fi
}

# Export functions for use in other scripts
export -f generate_project_id
export -f get_project_id
export -f prompt_project_id
export -f clear_project_id
export -f validate_project_id
export -f check_project_id_availability
