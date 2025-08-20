#!/bin/bash

# GKE Setup Script for Confidential App
# This script sets up the necessary GCP resources for the application

set -e

# Source configuration functions
source "$(dirname "$0")/config.sh"

# Get or prompt for project ID
if [ ! -f ".project-config" ]; then
    echo "🔧 First time setup - configuring project ID..."
    PROJECT_ID=$(prompt_project_id)
else
    PROJECT_ID=$(get_project_id)
    echo "✅ Using existing project ID: $PROJECT_ID"
fi

# Step 1: Check if project exists, create if needed
echo ""
echo -e "${CYAN}📋 Step 1: Checking/Creating GCP Project${NC}"
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "🏗️  Creating new GCP project: $PROJECT_ID"
    if gcloud projects create "$PROJECT_ID" --name="GKE Demo Project" --set-as-default; then
        echo "✅ Project created successfully"
    else
        echo "❌ Failed to create project. Please check your permissions."
        exit 1
    fi
else
    echo "✅ Project $PROJECT_ID already exists"
fi

# Step 2: Check billing
echo ""
echo -e "${CYAN}📋 Step 2: Checking Billing${NC}"
billing_account=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
if [ -z "$billing_account" ] || [ "$billing_account" = "" ]; then
    echo "❌ Billing not enabled for project $PROJECT_ID"
    echo "💡 Please enable billing manually:"
    echo "   gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID"
    echo ""
    echo "Or visit: https://console.cloud.google.com/billing/projects"
    echo "Select project: $PROJECT_ID and link a billing account"
    echo ""
    read -p "Press Enter after enabling billing, or Ctrl+C to cancel..."
else
    echo "✅ Billing enabled: $billing_account"
fi

# Step 3: Enable APIs
echo ""
echo -e "${CYAN}📋 Step 3: Enabling Required APIs${NC}"
apis=(
    "compute.googleapis.com"
    "container.googleapis.com"
    "artifactregistry.googleapis.com"
    "iam.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

for api in "${apis[@]}"; do
    echo "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID"
    echo "✅ $api enabled"
done

# Configuration
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
