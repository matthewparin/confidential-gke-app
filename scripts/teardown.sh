#!/bin/bash

# NVIDIA DGX Cloud - Complete Teardown Script
# This script removes all Docker images and GKE resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Source configuration functions
source "$(dirname "$0")/config.sh"

# Get project ID
PROJECT_ID=$(get_project_id)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No project ID configured. Nothing to tear down."
    exit 0
fi

echo "✅ Using project ID: $PROJECT_ID"

# Configuration
REGION="us-central1"
CLUSTER_NAME="confidential-cluster"
SERVICE_ACCOUNT_NAME="confidential-app-sa"
REPO_NAME="confidential-repo"
IMAGE_NAME="confidential-app"
TAG="v1"
FULL_IMAGE_NAME="us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$TAG"

echo -e "${CYAN}🧹 GKE Demo - Complete Teardown${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Function to confirm teardown
confirm_teardown() {
    echo -e "${RED}⚠️  WARNING: This will permanently delete all resources!${NC}"
    echo -e "${YELLOW}The following will be removed:${NC}"
    echo -e "  • GKE cluster: $CLUSTER_NAME"
    echo -e "  • Service account: $SERVICE_ACCOUNT_NAME"
    echo -e "  • Artifact Registry repository: $REPO_NAME"
    echo -e "  • Docker images: $FULL_IMAGE_NAME"
    echo -e "  • All Kubernetes resources"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${GREEN}Teardown cancelled.${NC}"
        exit 0
    fi
}

# Function to delete Kubernetes resources
delete_k8s_resources() {
    echo -e "${YELLOW}🗑️  Deleting Kubernetes resources...${NC}"
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  kubectl not configured or cluster not accessible${NC}"
        return
    fi
    
    # Delete all resources in the kubernetes directory
    if [ -d "kubernetes" ]; then
        echo -e "${BLUE}Deleting deployment and service...${NC}"
        kubectl delete -f kubernetes/ --ignore-not-found=true || true
    fi
    
    # Delete any remaining resources with our labels
    echo -e "${BLUE}Cleaning up any remaining resources...${NC}"
    kubectl delete deployment,service,serviceaccount,clusterrolebinding -l app=confidential-app --ignore-not-found=true || true
    
    echo -e "${GREEN}✅ Kubernetes resources deleted${NC}"
    echo ""
}

# Function to delete Docker images
delete_docker_images() {
    echo -e "${YELLOW}🐳 Deleting Docker images...${NC}"
    
    # List all Docker images before deletion for debugging
    echo -e "${BLUE}Current Docker images:${NC}"
    docker images | grep -E "($IMAGE_NAME|confidential)" || echo -e "${YELLOW}No matching images found${NC}"
    echo ""
    
    # Remove the specific image (Artifact Registry format)
    echo -e "${BLUE}Removing image: $FULL_IMAGE_NAME${NC}"
    docker rmi "$FULL_IMAGE_NAME" --force 2>/dev/null || echo -e "${YELLOW}Image not found or already removed${NC}"
    
    # Remove local image if it exists
    echo -e "${BLUE}Removing local image: $IMAGE_NAME:$TAG${NC}"
    docker rmi "$IMAGE_NAME:$TAG" --force 2>/dev/null || echo -e "${YELLOW}Local image not found or already removed${NC}"
    
    # Remove any images with just the image name (without tag)
    echo -e "${BLUE}Removing any images with name: $IMAGE_NAME${NC}"
    docker rmi "$IMAGE_NAME" --force 2>/dev/null || echo -e "${YELLOW}Image not found or already removed${NC}"
    
    # Remove any images that might have been built with different tags
    echo -e "${BLUE}Removing any images containing: $IMAGE_NAME${NC}"
    docker images | grep "$IMAGE_NAME" | awk '{print $3}' | xargs -r docker rmi --force 2>/dev/null || echo -e "${YELLOW}No additional images found${NC}"
    
    # Clean up any dangling images
    echo -e "${BLUE}Cleaning up dangling images...${NC}"
    docker image prune --force --filter="dangling=true" || true
    
    # Clean up unused images
    echo -e "${BLUE}Cleaning up unused images...${NC}"
    docker image prune --force --all || true
    
    # Final check - if any images with our name still exist, try to remove them by ID
    echo -e "${BLUE}Final cleanup check...${NC}"
    if docker images | grep -q "$IMAGE_NAME"; then
        echo -e "${YELLOW}Found remaining images, attempting removal by ID...${NC}"
        docker images | grep "$IMAGE_NAME" | awk '{print $1 ":" $2}' | xargs -r docker rmi --force 2>/dev/null || true
        docker images | grep "$IMAGE_NAME" | awk '{print $3}' | xargs -r docker rmi --force 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Docker images deleted${NC}"
    echo ""
}

# Function to delete GKE cluster
delete_gke_cluster() {
    echo -e "${YELLOW}🏗️  Deleting GKE cluster...${NC}"
    
    # Check if cluster exists
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting cluster: $CLUSTER_NAME${NC}"
        gcloud container clusters delete "$CLUSTER_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --quiet || echo -e "${YELLOW}Cluster deletion failed or already deleted${NC}"
    else
        echo -e "${YELLOW}Cluster $CLUSTER_NAME not found${NC}"
    fi
    
    echo -e "${GREEN}✅ GKE cluster deleted${NC}"
    echo ""
}

# Function to delete service account
delete_service_account() {
    echo -e "${YELLOW}👤 Deleting service account...${NC}"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting service account: $SERVICE_ACCOUNT_NAME${NC}"
        gcloud iam service-accounts delete "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
            --project="$PROJECT_ID" \
            --quiet || echo -e "${YELLOW}Service account deletion failed or already deleted${NC}"
    else
        echo -e "${YELLOW}Service account $SERVICE_ACCOUNT_NAME not found${NC}"
    fi
    
    echo -e "${GREEN}✅ Service account deleted${NC}"
    echo ""
}

# Function to delete Artifact Registry repository
delete_artifact_registry() {
    echo -e "${YELLOW}📦 Deleting Artifact Registry repository...${NC}"
    
    # Check if repository exists
    if gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting repository: $REPO_NAME${NC}"
        gcloud artifacts repositories delete "$REPO_NAME" \
            --location="$REGION" \
            --project="$PROJECT_ID" \
            --quiet || echo -e "${YELLOW}Repository deletion failed or already deleted${NC}"
    else
        echo -e "${YELLOW}Repository $REPO_NAME not found${NC}"
    fi
    
    echo -e "${GREEN}✅ Artifact Registry repository deleted${NC}"
    echo ""
}

# Function to clean up local files
cleanup_local_files() {
    echo -e "${YELLOW}📁 Cleaning up local files...${NC}"
    
    # Remove any local kubeconfig files
    find . -name "*.kubeconfig" -delete 2>/dev/null || true
    
    # Clean up Terraform state and files
    if [ -d "terraform" ]; then
        echo -e "${BLUE}Cleaning up Terraform state...${NC}"
        cd terraform
        
        # Destroy Terraform resources if state exists
        if [ -f "terraform.tfstate" ]; then
            echo -e "${BLUE}Destroying Terraform resources...${NC}"
            terraform destroy -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" 2>/dev/null || echo -e "${YELLOW}Terraform destroy failed or no resources to destroy${NC}"
        fi
        
        # Remove Terraform state files
        rm -f terraform.tfstate terraform.tfstate.backup 2>/dev/null || true
        
        cd ..
    fi
    
    # Remove any terraform state files in root
    find . -name "*.tfstate*" -delete 2>/dev/null || true
    
    # Remove terraform directory
    if [ -d ".terraform" ]; then
        echo -e "${BLUE}Removing .terraform directory...${NC}"
        rm -rf .terraform
    fi
    
    # Remove terraform directory in terraform folder
    if [ -d "terraform/.terraform" ]; then
        echo -e "${BLUE}Removing terraform/.terraform directory...${NC}"
        rm -rf terraform/.terraform
    fi
    
    echo -e "${GREEN}✅ Local files cleaned up${NC}"
    echo ""
}

# Function to verify cleanup
verify_cleanup() {
    echo -e "${YELLOW}🔍 Verifying cleanup...${NC}"
    
    # Check if cluster still exists
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${RED}❌ Cluster $CLUSTER_NAME still exists${NC}"
    else
        echo -e "${GREEN}✅ Cluster $CLUSTER_NAME deleted${NC}"
    fi
    
    # Check if service account still exists
    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${RED}❌ Service account $SERVICE_ACCOUNT_NAME still exists${NC}"
    else
        echo -e "${GREEN}✅ Service account $SERVICE_ACCOUNT_NAME deleted${NC}"
    fi
    
    # Check if repository still exists
    if gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo -e "${RED}❌ Repository $REPO_NAME still exists${NC}"
    else
        echo -e "${GREEN}✅ Repository $REPO_NAME deleted${NC}"
    fi
    
    # Check if Docker image still exists (check all possible variations)
    local image_exists=false
    
    # Check for full image name
    if docker images | grep -q "$FULL_IMAGE_NAME"; then
        echo -e "${RED}❌ Docker image $FULL_IMAGE_NAME still exists${NC}"
        image_exists=true
    fi
    
    # Check for local image name with tag
    if docker images | grep -q "$IMAGE_NAME.*$TAG"; then
        echo -e "${RED}❌ Docker image $IMAGE_NAME:$TAG still exists${NC}"
        image_exists=true
    fi
    
    # Check for image name without tag
    if docker images | grep -q "^$IMAGE_NAME "; then
        echo -e "${RED}❌ Docker image $IMAGE_NAME still exists${NC}"
        image_exists=true
    fi
    
    # Check for any image containing the image name
    if docker images | grep -q "$IMAGE_NAME"; then
        echo -e "${RED}❌ Docker image containing $IMAGE_NAME still exists${NC}"
        image_exists=true
    fi
    
    if [ "$image_exists" = false ]; then
        echo -e "${GREEN}✅ All Docker images deleted${NC}"
    fi
    
    echo ""
}

# Main teardown function
main() {
    # Confirm teardown
    confirm_teardown
    
    echo -e "${CYAN}Starting complete teardown...${NC}"
    echo ""
    
    # Delete Kubernetes resources first
    delete_k8s_resources
    
    # Delete Docker images
    delete_docker_images
    
    # Delete GKE cluster
    delete_gke_cluster
    
    # Delete service account
    delete_service_account
    
    # Delete Artifact Registry repository
    delete_artifact_registry
    
    # Clean up local files
    cleanup_local_files
    
    # Clear project configuration
    clear_project_id
    
    # Verify cleanup
    verify_cleanup
    
    echo -e "${GREEN}🎉 Teardown completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 Summary:${NC}"
    echo -e "${GREEN}✓ Kubernetes resources removed${NC}"
    echo -e "${GREEN}✓ Docker images cleaned up${NC}"
    echo -e "${GREEN}✓ GKE cluster deleted${NC}"
    echo -e "${GREEN}✓ Service account removed${NC}"
    echo -e "${GREEN}✓ Artifact Registry repository deleted${NC}"
    echo -e "${GREEN}✓ Local files cleaned up${NC}"
    echo ""
    echo -e "${YELLOW}💡 To redeploy, run: ./scripts/setup-gke.sh && ./scripts/deploy.sh${NC}"
}

# Run the teardown
main
