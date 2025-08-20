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

# Step 6: Containerize the Python application
echo ""
echo -e "${CYAN}📋 Step 6: Containerizing Python Application${NC}"
echo "🏗️  Building Docker image..."
docker build -t $FULL_IMAGE_NAME .

# Verify the image was built successfully
echo "🔍 Verifying Docker image..."
if docker images | grep -q "$IMAGE_NAME"; then
    echo "✅ Docker image built successfully"
    docker images | grep "$IMAGE_NAME"
else
    echo "❌ Docker image build failed"
    exit 1
fi

# Test the container locally
echo "🧪 Testing container locally..."
if docker run --rm -d -p 5000:5000 --name test-container $FULL_IMAGE_NAME; then
    sleep 5
    if curl -s http://localhost:5000/api/v1/health > /dev/null; then
        echo "✅ Container test successful"
    else
        echo "❌ Container test failed - health check failed"
    fi
    docker stop test-container
else
    echo "❌ Container test failed - could not start container"
    exit 1
fi

# Step 7: Create Artifact Registry and configure Docker authentication
echo ""
echo -e "${CYAN}📋 Step 7: Setting up Artifact Registry${NC}"
echo "🔑 Configuring Docker authentication..."
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

# Create Artifact Registry repository if it doesn't exist
echo "🏗️  Creating Artifact Registry repository..."
if ! gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud artifacts repositories create "$REPO_NAME" \
        --repository-format=docker \
        --location="$REGION" \
        --project="$PROJECT_ID" \
        --description="Repository for GKE demo images"
    echo "✅ Artifact Registry repository created"
else
    echo "✅ Artifact Registry repository already exists"
fi

# Step 8: Verify fully-qualified image name
echo ""
echo -e "${CYAN}📋 Step 8: Verifying Image Name${NC}"
echo "🔍 Checking fully-qualified image name..."
echo "Image name: $FULL_IMAGE_NAME"
if [[ $FULL_IMAGE_NAME =~ ^us-central1-docker\.pkg\.dev/[a-z][a-z0-9-]{5,29}/[a-z0-9-]+/[a-z0-9-]+:v[0-9]+$ ]]; then
    echo "✅ Image name format is correct"
else
    echo "❌ Image name format is incorrect"
    exit 1
fi

# Step 9: Push the image to Artifact Registry
echo ""
echo -e "${CYAN}📋 Step 9: Pushing Image to Artifact Registry${NC}"
echo "📤 Pushing image to Artifact Registry..."
docker push $FULL_IMAGE_NAME

# Verify the image was pushed successfully
echo "🔍 Verifying image in Artifact Registry..."
if gcloud artifacts docker images list "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME" --format="table(NAME,TAGS)" | grep -q "$IMAGE_NAME"; then
    echo "✅ Image pushed successfully"
else
    echo "❌ Image push failed"
    exit 1
fi

# Step 10: Define infrastructure requirements (Terraform)
echo ""
echo -e "${CYAN}📋 Step 10: Defining Infrastructure Requirements${NC}"
echo "🏗️  Checking Terraform configuration..."
if [ -d "terraform" ] && [ -f "terraform/main.tf" ]; then
    echo "✅ Terraform configuration found"
    echo "💡 Note: Terraform deployment is optional for this demo"
    echo "   The setup script creates GKE cluster directly via gcloud"
else
    echo "⚠️  No Terraform configuration found - using gcloud for infrastructure"
fi

# Step 11: Plan and Deploy Terraform (if available)
if [ -d "terraform" ] && [ -f "terraform/main.tf" ]; then
    echo ""
    echo -e "${CYAN}📋 Step 11: Planning and Deploying Terraform${NC}"
    cd terraform
    terraform init
    terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION"
    terraform apply -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve
    cd ..
    echo "✅ Terraform deployment completed"
else
    echo ""
    echo -e "${CYAN}📋 Step 11: Using gcloud for Infrastructure${NC}"
    echo "✅ Infrastructure already set up via setup script"
fi

# Step 12: Deploy containerized application with Kubernetes
echo ""
echo -e "${CYAN}📋 Step 12: Deploying Application with Kubernetes${NC}"
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

echo "✅ Kubernetes deployment applied"

# Step 13: Apply the service to create load balancer
echo ""
echo -e "${CYAN}📋 Step 13: Creating Load Balancer Service${NC}"
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/confidential-app-deployment --timeout=300s

echo "🌐 Creating load balancer service..."
kubectl get service confidential-app-service

# Step 14: Get external IP and test application
echo ""
echo -e "${CYAN}📋 Step 14: Testing Application${NC}"
echo "🔍 Getting external IP address..."

# Wait for external IP to be assigned
echo "⏳ Waiting for external IP assignment..."
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get service confidential-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo "Waiting for external IP... (attempt $i/30)"
    sleep 10
done

if [ -n "$EXTERNAL_IP" ]; then
    echo "✅ External IP assigned: $EXTERNAL_IP"
    
    # Test the application
    echo "🧪 Testing application with curl..."
    sleep 10  # Give the load balancer time to route traffic
    
    if curl -s "http://$EXTERNAL_IP/api/v1/health" > /dev/null; then
        echo "✅ Application is responding!"
        echo ""
        echo -e "${GREEN}🎉 Deployment successful!${NC}"
        echo ""
        echo -e "${CYAN}📋 Application Details:${NC}"
        echo "🌐 External IP: $EXTERNAL_IP"
        echo "🔗 Dashboard: http://$EXTERNAL_IP"
        echo "🔗 Health Check: http://$EXTERNAL_IP/api/v1/health"
        echo "🔗 API Base: http://$EXTERNAL_IP/api/v1"
        echo ""
        echo -e "${YELLOW}💡 Test commands:${NC}"
        echo "curl http://$EXTERNAL_IP/api/v1/health"
        echo "curl -X POST http://$EXTERNAL_IP/api/v1/inference -H 'Content-Type: application/json' -d '{\"input\":{\"text\":\"test\"},\"model_type\":\"llm\"}'"
    else
        echo "❌ Application test failed"
        echo "💡 The application may still be starting up. Try again in a few minutes."
    fi
else
    echo "❌ External IP not assigned within timeout"
    echo "💡 Check the service status: kubectl get service confidential-app-service"
fi

echo "✅ Deployment complete!"
echo ""
echo "To check the application status:"
echo "  kubectl get pods"
echo "  kubectl logs -l app=confidential-app"
echo ""
echo "To access the application (once LoadBalancer IP is assigned):"
echo "  kubectl get service confidential-app-service"
