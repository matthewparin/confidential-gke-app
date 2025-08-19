#!/bin/bash

# NVIDIA DGX Cloud - Confidential AI Platform Demo Script
# This script demonstrates the enterprise-grade capabilities of the platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:5000"
API_BASE_URL="${BASE_URL}/api/v1"

echo -e "${CYAN}🚀 NVIDIA DGX Cloud - Confidential AI Platform Demo${NC}"
echo -e "${CYAN}==================================================${NC}"
echo ""

# Function to make API calls and display results
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}${description}${NC}"
    echo -e "${BLUE}${method} ${endpoint}${NC}"
    
    if [ -n "$data" ]; then
        echo -e "${PURPLE}Request Data:${NC} $data"
        response=$(curl -s -X "$method" "$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -X "$method" "$endpoint")
    fi
    
    echo -e "${GREEN}Response:${NC}"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    echo ""
}

# Function to check if service is running
check_service() {
    echo -e "${YELLOW}Checking if service is running...${NC}"
    if curl -s "$BASE_URL" > /dev/null; then
        echo -e "${GREEN}✅ Service is running${NC}"
        echo ""
    else
        echo -e "${RED}❌ Service is not running. Please start the application first.${NC}"
        echo -e "${YELLOW}Run: ./scripts/deploy.sh${NC}"
        exit 1
    fi
}

# Main demo flow
main() {
    check_service
    
    echo -e "${CYAN}📊 Demo 1: Platform Dashboard${NC}"
    echo -e "${BLUE}Opening dashboard in browser...${NC}"
    if command -v open >/dev/null 2>&1; then
        open "$BASE_URL"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$BASE_URL"
    else
        echo -e "${YELLOW}Please open: $BASE_URL${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}🔍 Demo 2: System Health Check${NC}"
    api_call "GET" "$API_BASE_URL/health" "" "Comprehensive health check with confidential computing status"
    
    echo -e "${CYAN}🤖 Demo 3: Secure Model Inference${NC}"
    api_call "POST" "$API_BASE_URL/inference" '{
        "input": {
            "text": "This is a confidential AI inference request",
            "parameters": {
                "temperature": 0.7,
                "max_tokens": 100
            }
        },
        "model_type": "llm"
    }' "Secure model inference with confidential computing guarantees"
    
    echo -e "${CYAN}📈 Demo 4: System Performance Metrics${NC}"
    api_call "GET" "$API_BASE_URL/metrics" "" "Comprehensive system performance and security metrics"
    
    echo -e "${CYAN}🔒 Demo 5: Security Audit Logs${NC}"
    api_call "GET" "$API_BASE_URL/audit" "" "Security audit logs for compliance and monitoring"
    
    echo -e "${CYAN}🎯 Demo 6: Training Job Management${NC}"
    api_call "POST" "$API_BASE_URL/training" '{
        "config": {
            "model_type": "transformer",
            "dataset": "confidential_enterprise_data",
            "hyperparameters": {
                "learning_rate": 0.001,
                "batch_size": 32,
                "epochs": 100
            },
            "gpu_requirements": "4x A100"
        }
    }' "Start confidential training job with encrypted data and model checkpoints"
    
    echo -e "${CYAN}🔄 Demo 7: Multiple Inference Requests${NC}"
    echo -e "${YELLOW}Running multiple inference requests to demonstrate throughput...${NC}"
    
    for i in {1..3}; do
        echo -e "${BLUE}Request $i:${NC}"
        api_call "POST" "$API_BASE_URL/inference" "{
            \"input\": {\"text\": \"Inference request $i\"},
            \"model_type\": \"llm\"
        }" "Inference request $i"
    done
    
    echo -e "${CYAN}📊 Demo 8: Updated Metrics After Activity${NC}"
    api_call "GET" "$API_BASE_URL/metrics" "" "Updated metrics showing increased activity"
    
    echo -e "${GREEN}✅ Demo completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}🎯 Key Platform Capabilities Demonstrated:${NC}"
    echo -e "${GREEN}✓ Confidential Computing with hardware-level encryption${NC}"
    echo -e "${GREEN}✓ Secure model inference and training${NC}"
    echo -e "${GREEN}✓ Real-time performance monitoring${NC}"
    echo -e "${GREEN}✓ Compliance audit trails${NC}"
    echo -e "${GREEN}✓ Enterprise-grade security${NC}"
    echo -e "${GREEN}✓ Cost optimization features${NC}"
    echo ""
    echo -e "${CYAN}🔗 Additional Resources:${NC}"
    echo -e "${BLUE}• API Documentation: docs/API_DOCUMENTATION.md${NC}"
    echo -e "${BLUE}• Dashboard: $BASE_URL${NC}"
    echo -e "${BLUE}• Health Check: $API_BASE_URL/health${NC}"
    echo ""
    echo -e "${YELLOW}💡 For a VP Product Management role at NVIDIA DGX Cloud, this demo showcases:${NC}"
    echo -e "${PURPLE}• Technical depth in AI/ML platforms${NC}"
    echo -e "${PURPLE}• Understanding of enterprise security requirements${NC}"
    echo -e "${PURPLE}• Knowledge of confidential computing${NC}"
    echo -e "${PURPLE}• Experience with cloud-native architectures${NC}"
    echo -e "${PURPLE}• Ability to build production-ready solutions${NC}"
}

# Run the demo
main
