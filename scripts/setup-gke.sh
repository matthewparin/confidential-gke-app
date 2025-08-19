#!/bin/bash

# GKE Setup Script for Confidential App
# This script sets up the necessary GCP resources for the application

set -e

# Configuration
PROJECT_ID="cc-demo-1755288433-mwp"
REGION="us-central1"
CLUSTER_NAME="confidential-cluster"
SERVICE_ACCOUNT_NAME="confidential-app-sa"
REPO_NAME="confidential-repo"

echo "🚀 Setting up GKE environment for confidential app..."

# Enable required APIs
echo "📋 Enabling required APIs..."
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable iam.googleapis.com

# Create Artifact Registry repository if it doesn't exist
echo "🏗️  Setting up Artifact Registry..."
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Repository for confidential app images" \
    --quiet || echo "Repository already exists"

# Create service account for the application
echo "👤 Creating service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Confidential App Service Account" \
    --description="Service account for confidential app deployment" \
    --quiet || echo "Service account already exists"

# Grant Artifact Registry Reader role
echo "🔐 Granting Artifact Registry permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"

# Grant GKE Node Service Account permissions
echo "🔐 Granting GKE permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/container.nodeServiceAccount"

# Create GKE cluster if it doesn't exist
echo "🏗️  Setting up GKE cluster..."
gcloud container clusters create $CLUSTER_NAME \
    --region=$REGION \
    --num-nodes=2 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --machine-type=e2-standard-2 \
    --enable-workload-identity \
    --quiet || echo "Cluster already exists"

# Get cluster credentials
echo "🔑 Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# Create namespace if it doesn't exist
echo "📁 Creating namespace..."
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Setup complete! You can now deploy your application."
echo ""
echo "Next steps:"
echo "1. Build and push your Docker image:"
echo "   docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/confidential-app:v1 ."
echo "   docker push us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/confidential-app:v1"
echo ""
echo "2. Apply Kubernetes manifests:"
echo "   kubectl apply -f kubernetes/"
echo ""
echo "3. Check deployment status:"
echo "   kubectl get pods"
echo "   kubectl get services"
