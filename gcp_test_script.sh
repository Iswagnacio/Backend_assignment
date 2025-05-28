#!/bin/bash

# GCP Authentication and Permissions Test Script
echo "🔐 Testing GCP Authentication and Permissions"
echo "=============================================="

PROJECT_ID="url-shortener-20250527232607"
SERVICE_ACCOUNT="url-shortener-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test 1: Check if gcloud is installed
echo "1. Checking gcloud installation..."
if command -v gcloud &> /dev/null; then
    print_status "gcloud CLI is installed"
    gcloud version
else
    print_error "gcloud CLI is not installed"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Test 2: Check authentication
echo -e "\n2. Checking current authentication..."
CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -n "$CURRENT_ACCOUNT" ]; then
    print_status "Authenticated as: $CURRENT_ACCOUNT"
else
    print_error "Not authenticated with gcloud"
    echo "Run: gcloud auth login"
    exit 1
fi

# Test 3: Check project access
echo -e "\n3. Testing project access..."
if gcloud projects describe $PROJECT_ID &>/dev/null; then
    print_status "Can access project: $PROJECT_ID"
else
    print_error "Cannot access project: $PROJECT_ID"
    echo "Make sure you have access to the project"
    exit 1
fi

# Test 4: Check service account existence
echo -e "\n4. Checking service account..."
if gcloud iam service-accounts describe $SERVICE_ACCOUNT --project=$PROJECT_ID &>/dev/null; then
    print_status "Service account exists: $SERVICE_ACCOUNT"
else
    print_error "Service account not found: $SERVICE_ACCOUNT"
    echo "Create it with Terraform or manually"
    exit 1
fi

# Test 5: Test Docker/GCR access
echo -e "\n5. Testing Container Registry access..."
if gcloud auth configure-docker --quiet; then
    print_status "Docker configured for GCR"
else
    print_warning "Failed to configure Docker for GCR"
fi

# Test 6: Check required APIs
echo -e "\n6. Checking required APIs..."
REQUIRED_APIS=(
    "run.googleapis.com"
    "containerregistry.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudsql.googleapis.com"
    "secretmanager.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --project=$PROJECT_ID --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        print_status "API enabled: $api"
    else
        print_warning "API not enabled: $api"
        echo "  Enable with: gcloud services enable $api --project=$PROJECT_ID"
    fi
done

# Test 7: Test service account permissions (if you have the key)
if [ -f "service-account-key.json" ]; then
    echo -e "\n7. Testing service account permissions..."
    export GOOGLE_APPLICATION_CREDENTIALS="service-account-key.json"
    
    if gcloud auth activate-service-account --key-file=service-account-key.json; then
        print_status "Service account authentication successful"
        
        # Test specific permissions
        echo "Testing Cloud Run permissions..."
        if gcloud run services list --project=$PROJECT_ID &>/dev/null; then
            print_status "Cloud Run access working"
        else
            print_warning "Cloud Run access failed"
        fi
        
    else
        print_error "Service account authentication failed"
    fi
else
    print_warning "service-account-key.json not found - skipping service account test"
    echo "  Download it with: gcloud iam service-accounts keys create service-account-key.json --iam-account=$SERVICE_ACCOUNT"
fi

echo -e "\n=============================================="
echo "🎯 GCP Testing completed!"
echo "If all tests passed, your GCP setup should work in GitHub Actions"