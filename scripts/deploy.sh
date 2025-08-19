#!/bin/bash

# Deployment Script for Confidential App
# This script builds, pushes, and deploys the application

set -e

# Configuration
PROJECT_ID="cc-demo-1755288433-mwp"
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

# Apply Kubernetes manifests
echo "📋 Applying Kubernetes manifests..."
kubectl apply -f kubernetes/

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
