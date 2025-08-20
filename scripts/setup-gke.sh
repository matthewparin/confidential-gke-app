#!/bin/bash

# GKE Setup Script for Confidential App
# This script sets up the necessary GCP resources for the application

set -e

# Source configuration functions
source "$(dirname "$0")/config.sh"

# Check permissions and authentication
echo ""
echo -e "${CYAN}🔐 Checking Permissions and Authentication${NC}"

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated to Google Cloud"
    echo "💡 Please authenticate first:"
    echo "   gcloud auth login"
    echo "   gcloud auth application-default login"
    exit 1
fi

# Get current user and organization info
CURRENT_USER=$(gcloud config get-value account)
CURRENT_ORG=$(gcloud organizations list --format="value(displayName)" 2>/dev/null || echo "No organization")
echo "✅ Authenticated as: $CURRENT_USER"
echo "📍 Organization: $CURRENT_ORG"

# Check for required permissions
echo "🔍 Checking required permissions..."

# Check if user can list projects (basic permission check)
if ! gcloud projects list --limit=1 >/dev/null 2>&1; then
    echo "❌ Insufficient permissions to list projects"
    echo "💡 You need at least 'Project Viewer' role"
    exit 1
fi

# Check if user can create projects (if needed)
if ! gcloud projects create --help >/dev/null 2>&1; then
    echo "⚠️  May not have project creation permissions"
    echo "💡 You might need 'Project Creator' role"
fi

# Check if user can manage billing
if ! gcloud billing accounts list >/dev/null 2>&1; then
    echo "⚠️  May not have billing management permissions"
    echo "💡 You might need 'Billing Account User' role"
fi

# Check if user can enable APIs
if ! gcloud services enable --help >/dev/null 2>&1; then
    echo "⚠️  May not have API management permissions"
    echo "💡 You might need 'Service Usage Admin' role"
fi

echo "✅ Permission checks completed"
echo ""

# Get or prompt for project ID
if [ ! -f ".project-config" ]; then
    echo "🔧 First time setup - configuring project ID..."
    PROJECT_ID=$(prompt_project_id)
else
    PROJECT_ID=$(get_project_id)
    echo "✅ Using existing project ID: $PROJECT_ID"
fi

# Validate project ID format
if ! validate_project_id "$PROJECT_ID"; then
    echo "❌ Invalid project ID format: $PROJECT_ID"
    echo "💡 Project ID must follow GCP naming rules:"
    echo "   - 6-30 characters"
    echo "   - Lowercase letters, numbers, and hyphens only"
    echo "   - Must start with a letter"
    echo "   - Cannot end with a hyphen"
    echo "   - Cannot contain consecutive hyphens"
    echo ""
    echo "🔄 Generating a new valid project ID..."
    NEW_PROJECT_ID=$(generate_project_id)
    echo "$NEW_PROJECT_ID" > "$CONFIG_FILE"
    PROJECT_ID="$NEW_PROJECT_ID"
    echo "✅ New project ID: $PROJECT_ID"
fi

# Step 1: Check if project exists, create if needed
echo ""
echo -e "${CYAN}📋 Step 1: Checking/Creating GCP Project${NC}"

# Check if project exists and user has access
if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Project $PROJECT_ID exists"
    
    # Check if user has access to this project
    echo "🔍 Checking project access..."
    if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:$CURRENT_USER" >/dev/null 2>&1; then
        echo "✅ You have access to project $PROJECT_ID"
    else
        echo "❌ You don't have access to project $PROJECT_ID"
        echo "💡 You need to be granted access to this project"
        echo "   Ask your project admin to add you with appropriate roles"
        exit 1
    fi
    
    # Set the project as default
    gcloud config set project "$PROJECT_ID"
    echo "✅ Set $PROJECT_ID as default project"
    
else
    echo "🏗️  Creating new GCP project: $PROJECT_ID"
    
    # Check if user has project creation permissions
    echo "🔍 Checking project creation permissions..."
    
    # Try to create the project
    if gcloud projects create "$PROJECT_ID" --name="GKE Demo Project" --set-as-default; then
        echo "✅ Project created successfully"
        
        # Grant the current user owner role on the new project
        echo "🔐 Granting project owner role to current user..."
        if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="user:$CURRENT_USER" \
            --role="roles/owner"; then
            echo "✅ Granted owner role to $CURRENT_USER"
        else
            echo "⚠️  Could not grant owner role (this is normal if you're not an org admin)"
        fi
        
    else
        echo "❌ Failed to create project: $PROJECT_ID"
        echo ""
        echo "🔧 Troubleshooting steps:"
        echo "1. Check if you have the 'Project Creator' role in your organization"
        echo "2. Verify the project ID is globally unique"
        echo "3. Ensure you're authenticated with the correct account"
        echo ""
        echo "💡 Alternative solutions:"
        echo "• Use an existing project ID instead"
        echo "• Ask your GCP admin to create the project for you"
        echo "• Use a different project ID format"
        echo ""
        echo "Current account: $CURRENT_USER"
        echo "Current organization: $CURRENT_ORG"
        echo ""
        read -p "Would you like to try with a different project ID? (y/n): " retry_choice
        if [[ $retry_choice =~ ^[Yy]$ ]]; then
            # Generate a new project ID and try again
            NEW_PROJECT_ID=$(generate_project_id)
            echo "🔄 Trying with new project ID: $NEW_PROJECT_ID"
            echo "$NEW_PROJECT_ID" > "$CONFIG_FILE"
            PROJECT_ID="$NEW_PROJECT_ID"
            
            if gcloud projects create "$PROJECT_ID" --name="GKE Demo Project" --set-as-default; then
                echo "✅ Project created successfully with new ID"
                
                # Grant the current user owner role on the new project
                echo "🔐 Granting project owner role to current user..."
                gcloud projects add-iam-policy-binding "$PROJECT_ID" \
                    --member="user:$CURRENT_USER" \
                    --role="roles/owner" || echo "⚠️  Could not grant owner role"
                    
            else
                echo "❌ Still unable to create project. Please use an existing project ID."
                echo "💡 Run: rm .project-config && ./scripts/setup-gke.sh"
                exit 1
            fi
        else
            echo "💡 Please use an existing project ID or contact your GCP administrator."
            exit 1
        fi
    fi
fi

# Step 2: Check and enable billing
echo ""
echo -e "${CYAN}📋 Step 2: Checking and Enabling Billing${NC}"

# Check if billing is already enabled
billing_account=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
if [ -n "$billing_account" ] && [ "$billing_account" != "" ]; then
    echo "✅ Billing already enabled: $billing_account"
else
    echo "💰 Billing not enabled for project $PROJECT_ID"
    echo "🔍 Looking for available billing accounts..."
    
    # List available billing accounts
    billing_accounts=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" 2>/dev/null || echo "")
    
    if [ -n "$billing_accounts" ]; then
        # Get the first available billing account
        first_billing_account=$(echo "$billing_accounts" | head -1)
        echo "✅ Found billing account: $first_billing_account"
        
        # Try to link the billing account
        echo "🔗 Linking billing account to project..."
        if gcloud billing projects link "$PROJECT_ID" --billing-account="$first_billing_account"; then
            echo "✅ Billing enabled successfully with account: $first_billing_account"
        else
            echo "❌ Failed to link billing account automatically"
            echo ""
            echo "💡 Manual billing setup required:"
            echo "1. Visit: https://console.cloud.google.com/billing/projects"
            echo "2. Select project: $PROJECT_ID"
            echo "3. Link a billing account"
            echo ""
            echo "Or run: gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID"
            echo ""
            read -p "Press Enter after enabling billing, or Ctrl+C to cancel..."
        fi
    else
        echo "❌ No billing accounts found"
        echo ""
        echo "💡 You need to create a billing account first:"
        echo "1. Visit: https://console.cloud.google.com/billing"
        echo "2. Create a new billing account"
        echo "3. Return here and run the setup again"
        echo ""
        read -p "Press Enter after creating a billing account, or Ctrl+C to cancel..."
        
        # Try again after user creates billing account
        billing_accounts=$(gcloud billing accounts list --format="value(ACCOUNT_ID)" 2>/dev/null || echo "")
        if [ -n "$billing_accounts" ]; then
            first_billing_account=$(echo "$billing_accounts" | head -1)
            echo "🔄 Linking billing account: $first_billing_account"
            if gcloud billing projects link "$PROJECT_ID" --billing-account="$first_billing_account"; then
                echo "✅ Billing enabled successfully"
            else
                echo "❌ Still unable to link billing account"
                exit 1
            fi
        else
            echo "❌ Still no billing accounts found"
            exit 1
        fi
    fi
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

# Create Artifact Registry repository if it doesn't exist
echo "🏗️  Setting up Artifact Registry..."
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Repository for confidential app images" \
    --quiet || echo "Repository already exists"

# Create service account for the application
echo "👤 Creating service account..."
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Service account $SERVICE_ACCOUNT_NAME already exists"
else
    echo "🏗️  Creating new service account: $SERVICE_ACCOUNT_NAME"
    if gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Confidential App Service Account" \
        --description="Service account for confidential app deployment" \
        --project="$PROJECT_ID"; then
        echo "✅ Service account created successfully"
    else
        echo "❌ Failed to create service account"
        echo "💡 This might be due to insufficient permissions"
        echo "   You need 'Service Account Admin' role"
        exit 1
    fi
fi

# Grant Artifact Registry Reader role
echo "🔐 Granting Artifact Registry permissions..."
if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"; then
    echo "✅ Artifact Registry permissions granted"
else
    echo "❌ Failed to grant Artifact Registry permissions"
    echo "💡 This might be due to insufficient permissions"
    echo "   You need 'Project IAM Admin' role"
    exit 1
fi

# Grant GKE Node Service Account permissions
echo "🔐 Granting GKE permissions..."
if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/container.nodeServiceAccount"; then
    echo "✅ GKE permissions granted"
else
    echo "❌ Failed to grant GKE permissions"
    echo "💡 This might be due to insufficient permissions"
    echo "   You need 'Project IAM Admin' role"
    exit 1
fi

# Verify service account exists and has proper permissions
echo "🔍 Verifying service account setup..."
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Service account verification successful"
else
    echo "❌ Service account verification failed"
    echo "💡 The service account was not created properly"
    exit 1
fi

# Create GKE cluster if it doesn't exist
echo "🏗️  Setting up GKE cluster..."
if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Cluster $CLUSTER_NAME already exists"
else
    # Check quota before creating cluster
    echo "🔍 Checking quota limits..."
    echo "💡 Note: GKE clusters require significant quota for SSD storage and compute resources"
    echo "   If creation fails, you may need to request quota increase"
    echo ""
    echo "🏗️  Creating new GKE cluster: $CLUSTER_NAME"
    
    # Check quota before creating cluster
    echo "🔍 Checking regional quota..."
    if gcloud compute regions describe "$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo "✅ Region $REGION is available"
    else
        echo "❌ Region $REGION is not available"
        exit 1
    fi
    
    # Try to create cluster with reduced resource requirements
    if gcloud container clusters create "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --num-nodes=1 \
        --enable-autoscaling \
        --min-nodes=1 \
        --max-nodes=3 \
        --machine-type=e2-standard-2 \
        --disk-size=50 \
        --disk-type=pd-standard \
        --enable-identity-service \
        --workload-pool="$PROJECT_ID.svc.id.goog" \
        --quiet; then
        echo "✅ GKE cluster created successfully"
    else
        echo "❌ Failed to create GKE cluster with standard settings"
        echo "💡 Trying with minimal settings..."
        
        # Try with even more minimal settings
        if gcloud container clusters create "$CLUSTER_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --num-nodes=1 \
            --machine-type=e2-micro \
            --disk-size=20 \
            --disk-type=pd-standard \
            --enable-identity-service \
            --workload-pool="$PROJECT_ID.svc.id.goog" \
            --quiet; then
            echo "✅ GKE cluster created successfully with minimal settings"
        else
            echo "❌ Failed to create GKE cluster even with minimal settings"
            echo ""
            echo "🔧 Troubleshooting steps:"
            echo "1. Check your quota limits:"
            echo "   https://console.cloud.google.com/iam-admin/quotas?usage=USED&project=$PROJECT_ID"
            echo ""
            echo "2. Request quota increase for:"
            echo "   - SSD_TOTAL_GB (currently 400GB, need at least 600GB)"
            echo "   - CPUS (for compute resources)"
            echo ""
            echo "3. Or try a different region:"
            echo "   gcloud compute regions list --filter='name~us-'"
            echo ""
            echo "4. Use an existing cluster instead"
            echo ""
            read -p "Would you like to try a different region? (y/n): " try_different_region
            if [[ $try_different_region =~ ^[Yy]$ ]]; then
                echo "🔄 Trying with region us-west1..."
                REGION="us-west1"
                if gcloud container clusters create "$CLUSTER_NAME" \
                    --region="$REGION" \
                    --project="$PROJECT_ID" \
                    --num-nodes=1 \
                    --machine-type=e2-standard-2 \
                    --disk-size=50 \
                    --disk-type=pd-standard \
                    --enable-identity-service \
                    --workload-pool="$PROJECT_ID.svc.id.goog" \
                    --quiet; then
                    echo "✅ GKE cluster created successfully in $REGION"
                else
                    echo "❌ Failed to create cluster in $REGION as well"
                    echo "💡 Please request quota increase or use an existing cluster"
                    exit 1
                fi
            else
                echo "💡 Please request quota increase or use an existing cluster"
                exit 1
            fi
        fi
    fi
fi

# Get cluster credentials
echo "🔑 Getting cluster credentials..."
if gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID"; then
    echo "✅ Cluster credentials retrieved successfully"
else
    echo "❌ Failed to get cluster credentials"
    echo "💡 This might be because:"
    echo "   - The cluster doesn't exist"
    echo "   - You don't have access to the cluster"
    echo "   - The cluster is in a different region"
    echo ""
    echo "🔍 Checking cluster status..."
    gcloud container clusters list --region="$REGION" --project="$PROJECT_ID"
    exit 1
fi

# Verify cluster is ready
echo "🔍 Verifying cluster is ready..."
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ Cluster is ready and accessible"
else
    echo "❌ Cluster is not ready or accessible"
    echo "💡 Waiting for cluster to be ready..."
    sleep 30
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Cluster is now ready"
    else
        echo "❌ Cluster is still not ready"
        echo "💡 Check cluster status: gcloud container clusters describe $CLUSTER_NAME --region=$REGION"
        exit 1
    fi
fi

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
