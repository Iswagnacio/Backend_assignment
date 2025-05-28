#!/bin/bash

# Local Testing Script for URL Shortener
echo "🚀 Starting Local Testing for URL Shortener"
echo "============================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test 1: Python Dependencies
echo "1. Testing Python Dependencies..."
if python -m pip install -r requirements.txt; then
    print_status "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    exit 1
fi

# Test 2: Code Quality
echo -e "\n2. Running Code Quality Checks..."
echo "Running flake8..."
flake8 main.py --extend-ignore=E501,W503 || print_warning "Linting issues found (non-blocking)"

echo "Running black..."
black --check main.py || print_warning "Code formatting issues (run 'black main.py' to fix)"

# Test 3: Unit Tests
echo -e "\n3. Running Unit Tests..."
if python windows_test.py; then
    print_status "All tests passed"
else
    print_warning "Some tests had issues (check logs above)"
fi

# Test 4: Local Server Test
echo -e "\n4. Testing Local Server..."
echo "Starting server in background..."
python -m uvicorn main:app --host 0.0.0.0 --port 8000 &
SERVER_PID=$!

# Wait for server to start
sleep 5

# Test endpoints
echo "Testing health endpoint..."
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    print_status "Health endpoint working"
else
    print_error "Health endpoint failed"
fi

echo "Testing root endpoint..."
if curl -f http://localhost:8000/ > /dev/null 2>&1; then
    print_status "Root endpoint working"
else
    print_error "Root endpoint failed"
fi

echo "Testing URL shortening..."
RESPONSE=$(curl -s -X POST "http://localhost:8000/shorten" \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.example.com"}')

if echo "$RESPONSE" | grep -q "short_code"; then
    print_status "URL shortening working"
    SHORT_CODE=$(echo "$RESPONSE" | python -c "import sys, json; print(json.load(sys.stdin)['short_code'])")
    echo "Generated short code: $SHORT_CODE"
    
    # Test redirect
    echo "Testing redirect..."
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000/$SHORT_CODE" | grep -q "302"; then
        print_status "Redirect working"
    else
        print_warning "Redirect test failed"
    fi
    
    # Test analytics
    echo "Testing analytics..."
    if curl -f "http://localhost:8000/analytics/$SHORT_CODE" > /dev/null 2>&1; then
        print_status "Analytics working"
    else
        print_warning "Analytics test failed"
    fi
else
    print_error "URL shortening failed"
fi

# Kill server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

print_status "Local server testing completed"

echo -e "\n5. Docker Testing..."
echo "Building Docker image..."
if docker build -t url-shortener-test .; then
    print_status "Docker build successful"
    
    echo "Testing Docker container..."
    docker run -d --name url-shortener-test-container -p 8001:8000 url-shortener-test
    
    # Wait for container to start
    sleep 10
    
    if curl -f http://localhost:8001/health > /dev/null 2>&1; then
        print_status "Docker container working"
    else
        print_error "Docker container failed"
    fi
    
    # Cleanup
    docker stop url-shortener-test-container > /dev/null 2>&1 || true
    docker rm url-shortener-test-container > /dev/null 2>&1 || true
else
    print_error "Docker build failed"
fi

echo -e "\n============================================="
echo "🎉 Local testing completed!"
echo "If all tests passed, you're ready to push to GitHub!"
