#!/bin/bash

# Show current project configuration
# This script displays the current project ID and configuration

# Source configuration functions
source "$(dirname "$0")/config.sh"

echo "🔧 GKE Demo Project Configuration"
echo "=================================="
echo ""

if [ -f ".project-config" ]; then
    PROJECT_ID=$(get_project_id)
    echo "✅ Project ID: $PROJECT_ID"
    echo "📍 Region: us-central1"
    echo "🏗️  Cluster: confidential-cluster"
    echo "👤 Service Account: confidential-app-sa"
    echo "📦 Repository: confidential-repo"
    echo ""
    echo "💡 To change the project ID, delete .project-config and run setup again"
else
    echo "❌ No project configuration found"
    echo ""
    echo "💡 Run ./scripts/setup-gke.sh to configure the project"
fi
