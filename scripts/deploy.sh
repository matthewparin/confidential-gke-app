#!/bin/bash

# Deployment Script for Confidential App
# This script builds, pushes, and deploys the application

set -e

# Source configuration functions
source "$(dirname "$0")/config.sh"

# Get project ID
PROJECT_ID=$(get_project_id)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No project ID configured. Please run setup first: ./scripts/setup-gke.sh"
    exit 1
fi

echo "✅ Using project ID: $PROJECT_ID"

# Configuration
REGION="us-central1"
REPO_NAME="confidential-repo"
IMAGE_NAME="confidential-app"
TAG="v1"
FULL_IMAGE_NAME="us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$TAG"

echo "🚀 Starting deployment process..."

# Configure Docker to use gcloud as a credential helper
echo "🔑 Configuring Docker authentication..."
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

# Build the Docker image
echo "🏗️  Building Docker image..."
docker build -t $FULL_IMAGE_NAME .

# Push the image to Artifact Registry
echo "📤 Pushing image to Artifact Registry..."
docker push $FULL_IMAGE_NAME

# Apply Kubernetes manifests with project ID replacement
echo "📋 Applying Kubernetes manifests..."
# Create a temporary directory for modified manifests
TEMP_DIR=$(mktemp -d)
cp -r kubernetes/* "$TEMP_DIR/"

# Replace PROJECT_ID_PLACEHOLDER with actual project ID in all files
find "$TEMP_DIR" -name "*.yaml" -exec sed -i.bak "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/g" {} \;

# Apply the modified manifests
kubectl apply -f "$TEMP_DIR/"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/confidential-app-deployment --timeout=300s

# Get service information
echo "🌐 Getting service information..."
kubectl get service confidential-app-service

echo "✅ Deployment complete!"
echo ""
echo "To check the application status:"
echo "  kubectl get pods"
echo "  kubectl logs -l app=confidential-app"
echo ""
echo "To access the application (once LoadBalancer IP is assigned):"
echo "  kubectl get service confidential-app-service"
