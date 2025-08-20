#!/bin/bash

# Prerequisites Check Script for GKE Demo
# This script validates all requirements before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 GKE Demo - Prerequisites Check${NC}"
echo -e "${CYAN}===============================${NC}"
echo ""

# Function to check command availability
check_command() {
    local cmd=$1
    local name=$2
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $name is installed${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is not installed${NC}"
        return 1
    fi
}

# Function to check GCP authentication
check_gcp_auth() {
    echo -e "${BLUE}🔐 Checking GCP authentication...${NC}"
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
        echo -e "${GREEN}✅ Authenticated as: $account${NC}"
        return 0
    else
        echo -e "${RED}❌ Not authenticated to GCP${NC}"
        echo -e "${YELLOW}💡 Run: gcloud auth login${NC}"
        return 1
    fi
}

# Function to check if project exists
check_project_exists() {
    local project_id=$1
    echo -e "${BLUE}🏗️  Checking if project exists: $project_id${NC}"
    
    if gcloud projects describe "$project_id" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Project $project_id exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Project $project_id does not exist${NC}"
        return 1
    fi
}

# Function to create project
create_project() {
    local project_id=$1
    echo -e "${BLUE}🏗️  Creating project: $project_id${NC}"
    
    if gcloud projects create "$project_id" --name="GKE Demo Project" --set-as-default; then
        echo -e "${GREEN}✅ Project $project_id created successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create project $project_id${NC}"
        return 1
    fi
}

# Function to check billing
check_billing() {
    local project_id=$1
    echo -e "${BLUE}💰 Checking billing for project: $project_id${NC}"
    
    local billing_account=$(gcloud billing projects describe "$project_id" --format="value(billingAccountName)" 2>/dev/null || echo "")
    
    if [ -n "$billing_account" ] && [ "$billing_account" != "" ]; then
        echo -e "${GREEN}✅ Billing enabled: $billing_account${NC}"
        return 0
    else
        echo -e "${RED}❌ Billing not enabled for project $project_id${NC}"
        echo -e "${YELLOW}💡 Run: gcloud billing projects link $project_id --billing-account=BILLING_ACCOUNT_ID${NC}"
        return 1
    fi
}

# Function to enable APIs
enable_apis() {
    local project_id=$1
    echo -e "${BLUE}🔌 Enabling required APIs...${NC}"
    
    local apis=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "artifactregistry.googleapis.com"
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        echo -e "${BLUE}Enabling $api...${NC}"
        if gcloud services enable "$api" --project="$project_id"; then
            echo -e "${GREEN}✅ $api enabled${NC}"
        else
            echo -e "${RED}❌ Failed to enable $api${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to check project structure
check_project_structure() {
    echo -e "${BLUE}📁 Checking project structure...${NC}"
    
    local required_files=(
        "app/app.py"
        "app/requirements.txt"
        "Dockerfile"
        "kubernetes/deployment.yaml"
        "kubernetes/service.yaml"
        "kubernetes/service-account.yaml"
        "scripts/setup-gke.sh"
        "scripts/deploy.sh"
        "scripts/teardown.sh"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}✅ $file exists${NC}"
        else
            echo -e "${RED}❌ $file missing${NC}"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All required files present${NC}"
        return 0
    else
        echo -e "${RED}❌ Missing files: ${missing_files[*]}${NC}"
        return 1
    fi
}

# Function to check Docker
check_docker() {
    echo -e "${BLUE}🐳 Checking Docker...${NC}"
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        echo -e "${YELLOW}💡 Start Docker and try again${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Docker is running${NC}"
    return 0
}

# Main function
main() {
    local all_checks_passed=true
    
    # Step 1: Check for required tools
    echo -e "${CYAN}📋 Step 1: Checking required tools...${NC}"
    echo ""
    
    check_command "gcloud" "Google Cloud CLI" || all_checks_passed=false
    check_command "docker" "Docker" || all_checks_passed=false
    check_command "kubectl" "kubectl" || all_checks_passed=false
    check_command "terraform" "Terraform" || all_checks_passed=false
    
    echo ""
    
    # Step 2: Check GCP authentication
    echo -e "${CYAN}📋 Step 2: Checking GCP authentication...${NC}"
    echo ""
    
    check_gcp_auth || {
        echo -e "${YELLOW}💡 Please authenticate to GCP first:${NC}"
        echo -e "${BLUE}   gcloud auth login${NC}"
        echo -e "${BLUE}   gcloud auth application-default login${NC}"
        all_checks_passed=false
    }
    
    echo ""
    
    # Step 3: Get or create project ID
    echo -e "${CYAN}📋 Step 3: Checking project configuration...${NC}"
    echo ""
    
    # Source configuration functions
    source "$(dirname "$0")/config.sh"
    
    local project_id
    if [ -f ".project-config" ]; then
        project_id=$(get_project_id)
        echo -e "${GREEN}✅ Using configured project ID: $project_id${NC}"
    else
        echo -e "${YELLOW}⚠️  No project configured. Will be set up during deployment.${NC}"
        project_id=""
    fi
    
    # Step 4: Check project structure
    echo ""
    echo -e "${CYAN}📋 Step 4: Checking project structure...${NC}"
    echo ""
    
    check_project_structure || all_checks_passed=false
    
    # Step 5: Check Docker
    echo ""
    echo -e "${CYAN}📋 Step 5: Checking Docker...${NC}"
    echo ""
    
    check_docker || all_checks_passed=false
    
    # Summary
    echo ""
    echo -e "${CYAN}📋 Summary${NC}"
    echo "========="
    
    if [ "$all_checks_passed" = true ]; then
        echo -e "${GREEN}✅ All prerequisites met! You can proceed with deployment.${NC}"
        echo ""
        echo -e "${YELLOW}💡 Next steps:${NC}"
        echo -e "${BLUE}   1. Run: ./scripts/setup-gke.sh${NC}"
        echo -e "${BLUE}   2. Run: ./scripts/deploy.sh${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some prerequisites are not met. Please fix the issues above.${NC}"
        echo ""
        echo -e "${YELLOW}💡 Common fixes:${NC}"
        echo -e "${BLUE}   • Install missing tools (gcloud, docker, kubectl, terraform)${NC}"
        echo -e "${BLUE}   • Authenticate to GCP: gcloud auth login${NC}"
        echo -e "${BLUE}   • Start Docker${NC}"
        echo -e "${BLUE}   • Ensure all project files are present${NC}"
        exit 1
    fi
}

# Run the main function
main
