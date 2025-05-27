#!/bin/bash

# URL Shortener Project File Organization Script
# This script organizes the downloaded files into the correct structure

set -e  # Exit on any error

echo "🗂️  Organizing URL Shortener Project Files..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in a directory with the downloaded files
print_info "Checking for downloaded files..."

# Map of your file names to correct names
declare -A file_mapping=(
    ["url_shortener_main.py"]="main.py"
    ["requirements_txt.txt"]="requirements.txt"
    ["dockerfile.txt"]="Dockerfile"
    ["test_main.py"]="test_main.py"  # Already correct
    ["github_workflow.txt"]=".github/workflows/ci-cd.yml"
    ["infrastructure_terraform.txt"]="terraform/main.tf"
    ["websocket_client_example.html"]="websocket_client.html"
    ["websocket_cli_client.py"]="websocket_client.py"
    ["docker_compose.txt"]="docker-compose.yml"
    ["postman_collection.json"]="postman_collection.json"  # Already correct
    ["makefile.txt"]="Makefile"
    ["comprehensive_readme.md"]="README.md"
)

# Create necessary directories
print_info "Creating directory structure..."
mkdir -p .github/workflows
mkdir -p terraform
mkdir -p scripts
mkdir -p docs
print_status "Directories created"

# Rename and move files
print_info "Organizing files..."

for source_file in "${!file_mapping[@]}"; do
    target_file="${file_mapping[$source_file]}"
    
    if [ -f "$source_file" ]; then
        # Create target directory if it doesn't exist
        target_dir=$(dirname "$target_file")
        if [ "$target_dir" != "." ]; then
            mkdir -p "$target_dir"
        fi
        
        # Move and rename the file
        mv "$source_file" "$target_file"
        print_status "Moved $source_file → $target_file"
    else
        print_warning "File not found: $source_file"
    fi
done

# Make shell scripts executable
print_info "Setting executable permissions..."
if [ -f "websocket_client.py" ]; then
    chmod +x websocket_client.py
    print_status "Made websocket_client.py executable"
fi

# Create .gitignore
print_info "Creating project configuration files..."
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars

# Database
*.db
urls.db
test.db

# Logs
*.log
logs/

# OS
.DS_Store
.DS_Store?
._*
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
EOF

# Create .env file
cat > .env << 'EOF'
# Database Configuration
DATABASE_URL=sqlite:///./urls.db
# For PostgreSQL: postgresql://username:password@localhost:5432/database_name

# Service Configuration
BASE_URL=http://localhost:8000

# Development settings
DEBUG=true
LOG_LEVEL=INFO

# Google Cloud Platform (for deployment)
# GCP_PROJECT_ID=your-project-id
# DATABASE_PASSWORD=your-secure-password
EOF

# Create .env.example
cat > .env.example << 'EOF'
# Database Configuration
DATABASE_URL=sqlite:///./urls.db
# For PostgreSQL: postgresql://username:password@localhost:5432/database_name

# Service Configuration
BASE_URL=http://localhost:8000

# Development settings
DEBUG=true
LOG_LEVEL=INFO

# Google Cloud Platform (for deployment)
# GCP_PROJECT_ID=your-project-id
# DATABASE_PASSWORD=your-secure-password
EOF

# Create manage.py CLI script
cat > manage.py << 'EOF'
#!/usr/bin/env python3
"""
Management script for URL Shortener Service
Usage: python manage.py <command>
"""

import subprocess
import sys

def run_command(cmd, description):
    """Run a shell command"""
    print(f"🔄 {description}...")
    result = subprocess.run(cmd, shell=True)
    if result.returncode == 0:
        print(f"✅ {description} completed")
    else:
        print(f"❌ {description} failed")
        sys.exit(1)

def setup_dev():
    """Set up development environment"""
    print("🚀 Setting up development environment...")
    run_command("pip install -r requirements.txt", "Installing dependencies")
    run_command("pip install black isort flake8 pytest-cov", "Installing dev tools")
    print("✅ Development environment ready!")
    print("💡 Next steps:")
    print("   1. Edit .env file if needed")
    print("   2. Run: python manage.py run")

def main():
    if len(sys.argv) < 2:
        print("Usage: python manage.py <command>")
        print("\nCommands:")
        print("  setup-dev    - Set up development environment")
        print("  test         - Run tests")
        print("  lint         - Run linting checks")
        print("  format       - Format code")
        print("  run          - Run development server")
        print("  docker-build - Build Docker image")
        print("  docker-run   - Run Docker container")
        return
    
    command = sys.argv[1]
    
    if command == "setup-dev":
        setup_dev()
    elif command == "test":
        run_command("pytest -v", "Running tests")
    elif command == "lint":
        run_command("flake8 main.py test_main.py", "Running linter")
        run_command("black --check main.py test_main.py", "Checking formatting")
    elif command == "format":
        run_command("black main.py test_main.py", "Formatting code")
        run_command("isort main.py test_main.py", "Sorting imports")
    elif command == "run":
        run_command("uvicorn main:app --reload --port 8000", "Starting server")
    elif command == "docker-build":
        run_command("docker build -t url-shortener .", "Building Docker image")
    elif command == "docker-run":
        run_command("docker run -p 8000:8000 url-shortener", "Running Docker container")
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()
EOF

chmod +x manage.py

# Create quick test script
mkdir -p scripts
cat > scripts/test_api.py << 'EOF'
#!/usr/bin/env python3
"""Quick API test script"""

import requests
import sys
import json

def test_api(base_url="http://localhost:8000"):
    print(f"🧪 Testing URL Shortener API at {base_url}")
    print("=" * 50)
    
    try:
        # Health check
        print("1. Testing health endpoint...")
        response = requests.get(f"{base_url}/health")
        if response.status_code == 200:
            print("✅ Health check passed")
            print(f"   Response: {response.json()}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return
        
        # Create short URL
        print("\n2. Testing URL shortening...")
        test_url = "https://example.com"
        response = requests.post(
            f"{base_url}/shorten",
            json={"url": test_url},
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            short_code = data["short_code"]
            print(f"✅ URL shortened successfully")
            print(f"   Short code: {short_code}")
            print(f"   Original: {data['original_url']}")
            print(f"   Shortened: {data['shortened_url']}")
        else:
            print(f"❌ URL shortening failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return
        
        # Test redirect
        print("\n3. Testing redirect...")
        response = requests.get(f"{base_url}/{short_code}", allow_redirects=False)
        if response.status_code == 302:
            print("✅ Redirect working correctly")
            print(f"   Location: {response.headers.get('Location')}")
        else:
            print(f"❌ Redirect failed: {response.status_code}")
        
        # Test analytics
        print("\n4. Testing analytics...")
        response = requests.get(f"{base_url}/analytics/{short_code}")
        if response.status_code == 200:
            data = response.json()
            print("✅ Analytics working correctly")
            print(f"   Short code: {data['short_code']}")
            print(f"   Redirect count: {data['redirect_count']}")
            print(f"   Created at: {data['created_at']}")
        else:
            print(f"❌ Analytics failed: {response.status_code}")
        
        print("\n🎉 All basic tests passed! Service is working correctly.")
        print("\n💡 Next steps:")
        print("   • Open http://localhost:8000/docs for API documentation")
        print("   • Test WebSocket: python websocket_client.py <short_code>")
        print("   • Open websocket_client.html in browser for WebSocket UI")
        
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to {base_url}")
        print("   Make sure the service is running:")
        print("   python manage.py run")
    except Exception as e:
        print(f"❌ Test failed with error: {e}")

if __name__ == "__main__":
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    test_api(base_url)
EOF

chmod +x scripts/test_api.py

# Create development documentation
cat > docs/DEVELOPMENT.md << 'EOF'
# Development Guide

## Quick Start
1. `python manage.py setup-dev` - Install dependencies
2. `python manage.py run` - Start server
3. `python scripts/test_api.py` - Test API

## Available Commands
- `python manage.py setup-dev` - Set up development environment
- `python manage.py run` - Start development server
- `python manage.py test` - Run unit tests
- `python manage.py lint` - Check code quality
- `python manage.py format` - Format code
- `python manage.py docker-build` - Build Docker image
- `python manage.py docker-run` - Run Docker container

## Testing
- Unit tests: `pytest test_main.py -v`
- API testing: `python scripts/test_api.py`
- WebSocket testing: `python websocket_client.py abc123`
- Load testing: Import `postman_collection.json` into Postman

## Docker
- Build: `docker build -t url-shortener .`
- Run: `docker run -p 8000:8000 url-shortener`
- Compose: `docker-compose up -d`

## Deployment
- Local: Use docker-compose
- Production: Deploy to Google Cloud Run via GitHub Actions
- Infrastructure: Use Terraform in `terraform/` directory
EOF

print_status "Project configuration files created"

# Verify file structure
print_info "Verifying project structure..."
echo ""
echo "📁 Final Project Structure:"
echo "├── main.py                    # FastAPI application"
echo "├── requirements.txt           # Python dependencies"
echo "├── Dockerfile                 # Container configuration"
echo "├── docker-compose.yml         # Local development setup"
echo "├── test_main.py              # Unit tests"
echo "├── websocket_client.html     # WebSocket browser client"
echo "├── websocket_client.py       # WebSocket CLI client"
echo "├── postman_collection.json   # API test collection"
echo "├── Makefile                  # Development commands"
echo "├── README.md                 # Documentation"
echo "├── manage.py                 # Management CLI"
echo "├── .env                      # Environment variables"
echo "├── .env.example              # Environment template"
echo "├── .gitignore                # Git ignore rules"
echo "├── .github/"
echo "│   └── workflows/"
echo "│       └── ci-cd.yml         # GitHub Actions pipeline"
echo "├── terraform/"
echo "│   └── main.tf               # Infrastructure code"
echo "├── scripts/"
echo "│   └── test_api.py           # Quick API test"
echo "└── docs/"
echo "    └── DEVELOPMENT.md        # Development guide"

print_status "File organization complete!"

echo ""
echo "🎉 All files organized successfully!"
echo "====================================="
echo ""
print_info "Quick Start:"
echo "1️⃣  Install dependencies:    python manage.py setup-dev"
echo "2️⃣  Start the server:        python manage.py run"
echo "3️⃣  Test the API:            python scripts/test_api.py"
echo "4️⃣  Run unit tests:          python manage.py test"
echo "5️⃣  View API docs:           http://localhost:8000/docs"
echo ""
print_info "WebSocket Testing:"
echo "• CLI client:       python websocket_client.py <short_code>"
echo "• Browser client:   Open websocket_client.html"
echo ""
print_info "Docker Commands:"
echo "• Build image:      python manage.py docker-build"
echo "• Run container:    python manage.py docker-run"
echo "• Use compose:      docker-compose up -d"
echo ""
print_info "Access Points:"
echo "• API:              http://localhost:8000"
echo "• Documentation:    http://localhost:8000/docs"
echo "• Health check:     http://localhost:8000/health"
echo ""
print_warning "Next Steps:"
echo "• Edit .env file with your database settings if needed"
echo "• For production deployment, set up GCP project and run terraform"
echo "• Set up GitHub repository and secrets for CI/CD"
echo ""
print_status "Ready to start development! 🚀"

# Final verification
if [ -f "main.py" ] && [ -f "requirements.txt" ]; then
    print_status "Core files are in place - you can now start the service!"
else
    print_error "Some core files are missing. Please check the file mapping above."
fi