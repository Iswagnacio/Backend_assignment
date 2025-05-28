#!/bin/bash

# Manual API Testing Script
echo "🧪 Manual API Testing for URL Shortener"
echo "======================================="

BASE_URL="${1:-http://localhost:8000}"
echo "Testing API at: $BASE_URL"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}🔍 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local description=$5
    
    print_test "$description"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL$endpoint" \
                       -H "Content-Type: application/json" \
                       -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "$expected_status" ]; then
        print_success "Status: $http_code ✓"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        print_error "Expected: $expected_status, Got: $http_code"
        echo "$body"
    fi
    echo ""
}

# Test 1: Health Check
test_endpoint "GET" "/health" "" "200" "Testing health endpoint"

# Test 2: Root endpoint
test_endpoint "GET" "/" "" "200" "Testing root endpoint"

# Test 3: Create short URL
print_test "Creating short URL"
response=$(curl -s -X POST "$BASE_URL/shorten" \
               -H "Content-Type: application/json" \
               -d '{"url": "https://www.example.com"}')

if echo "$response" | jq . &>/dev/null; then
    print_success "Short URL created successfully"
    echo "$response" | jq .
    SHORT_CODE=$(echo "$response" | jq -r '.short_code')
    echo "Short code: $SHORT_CODE"
else
    print_error "Failed to create short URL"
    echo "$response"
    exit 1
fi

# Test 4: Test redirect
if [ -n "$SHORT_CODE" ]; then
    echo ""
    print_test "Testing redirect for /$SHORT_CODE"
    redirect_response=$(curl -s -w "%{http_code}|%{redirect_url}" -o /dev/null "$BASE_URL/$SHORT_CODE")
    
    http_code=$(echo "$redirect_response" | cut -d'|' -f1)
    redirect_url=$(echo "$redirect_response" | cut -d'|' -f2)
    
    if [ "$http_code" = "302" ]; then
        print_success "Redirect working - Status: $http_code"
        echo "Redirects to: $redirect_url"
    else
        print_error "Redirect failed - Status: $http_code"
    fi
fi

# Test 5: Test analytics
if [ -n "$SHORT_CODE" ]; then
    echo ""
    test_endpoint "GET" "/analytics/$SHORT_CODE" "" "200" "Testing analytics endpoint"
fi

# Test 6: Error cases
echo ""
print_test "Testing error cases"

echo "1. Invalid URL:"
test_endpoint "POST" "/shorten" '{"url": "not-a-url"}' "422" "Invalid URL handling"

echo "2. Non-existent short code redirect:"
test_endpoint "GET" "/nonexistent" "" "404" "Non-existent redirect"

echo "3. Non-existent analytics:"
test_endpoint "GET" "/analytics/nonexistent" "" "404" "Non-existent analytics"

# Test 7: WebSocket (if wscat is available)
if command -v wscat &> /dev/null && [ -n "$SHORT_CODE" ]; then
    echo ""
    print_test "Testing WebSocket connection"
    WS_URL="${BASE_URL/http/ws}/ws/analytics/$SHORT_CODE"
    echo "WebSocket URL: $WS_URL"
    echo "Run manually: wscat -c '$WS_URL'"
else
    echo ""
    print_test "WebSocket testing (manual)"
    echo "Install wscat to test: npm install -g wscat"
    echo "Then run: wscat -c '${BASE_URL/http/ws}/ws/analytics/$SHORT_CODE'"
fi

echo ""
echo "======================================="
echo "🎉 API testing completed!"
echo ""
echo "📝 Next steps to test WebSocket:"
echo "1. Open websocket_client.html in browser"
echo "2. Or run: python websocket_client.py $SHORT_CODE"
echo ""
echo "🐳 To test with Docker:"
echo "1. docker build -t url-shortener-test ."
echo "2. docker run -p 8001:8000 url-shortener-test"
echo "3. ./test_api.sh http://localhost:8001"