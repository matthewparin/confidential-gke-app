#!/bin/bash

# Configuration management for the GKE Demo project
# This script handles dynamic project ID generation and persistence

CONFIG_FILE=".project-config"

# Function to generate a unique project ID
generate_project_id() {
    local timestamp=$(date +%s)
    local random_suffix=$(printf "%04d" $((RANDOM % 10000)))
    echo "gke-demo-${timestamp}-${random_suffix}"
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
    if [[ $project_id =~ ^[a-z][a-z0-9-]{5,29}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use in other scripts
export -f generate_project_id
export -f get_project_id
export -f prompt_project_id
export -f clear_project_id
export -f validate_project_id
