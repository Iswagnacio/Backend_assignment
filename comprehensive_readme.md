# URL Shortener Service

A high-performance URL shortener service built with FastAPI, featuring real-time analytics via WebSocket, containerization with Docker, CI/CD with GitHub Actions, and deployment to Google Cloud Run.

## 🚀 Features

- **RESTful API** for creating and managing short URLs
- **Real-time Analytics** via WebSocket connections
- **Scalable Architecture** with Cloud Run deployment
- **Database Support** for PostgreSQL/MySQL (Cloud SQL ready)
- **CI/CD Pipeline** with GitHub Actions
- **Infrastructure as Code** with Terraform
- **Comprehensive Testing** with pytest
- **Security Best Practices** with IAM and Secret Manager
- **Monitoring & Alerting** with Cloud Monitoring

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/shorten` | Create a shortened URL |
| `GET` | `/{short_code}` | Redirect to original URL |
| `GET` | `/analytics/{short_code}` | Get analytics for short URL |
| `WS` | `/ws/analytics/{short_code}` | Real-time analytics updates |
| `GET` | `/health` | Health check endpoint |

## 🏃‍♂️ Quick Start

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd url-shortener
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **Access the API**
   - API: http://localhost:8000
   - Interactive docs: http://localhost:8000/docs
   - WebSocket client: Open `websocket_client.html` in your browser

### Using Docker

1. **Build the image**
   ```bash
   docker build -t url-shortener .
   ```

2. **Run the container**
   ```bash
   docker run -p 8000:8000 url-shortener
   ```

## 🧪 Testing

Run the test suite:
```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=main --cov-report=html

# Run specific test categories
pytest -k "test_shorten_url"
```

## 📝 API Usage Examples

### Create a Short URL
```bash
curl -X POST "http://localhost:8000/shorten" \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.example.com"}'
```

Response:
```json
{
  "short_code": "abc123",
  "shortened_url": "http://localhost:8000/abc123",
  "original_url": "https://www.example.com"
}
```

### Access Short URL
```bash
curl -L "http://localhost:8000/abc123"
# Redirects to https://www.example.com
```

### Get Analytics
```bash
curl "http://localhost:8000/analytics/abc123"
```

Response:
```json
{
  "short_code": "abc123",
  "original_url": "https://www.example.com",
  "redirect_count": 5,
  "created_at": "2024-01-15T10:30:00.000Z"
}
```

### WebSocket Real-time Analytics

#### Using the HTML Client
1. Open `websocket_client.html` in your browser
2. Enter a URL to shorten or use an existing short code
3. Connect to real-time analytics
4. Access the short URL in another tab to see live updates

#### Using the CLI Client
```bash
# Install additional dependencies
pip install websockets aiohttp

# Monitor analytics for a short code
python websocket_client.py abc123

# Create a short URL and monitor it
python websocket_client.py new_code --create "https://example.com"

# Connect to production
python websocket_client.py abc123 --url "wss://your-service-url.com"
```

## 🏗️ Infrastructure & Deployment

### Google Cloud Platform Setup

1. **Prerequisites**
   - Google Cloud Project with billing enabled
   - `gcloud` CLI installed and authenticated
   - Terraform installed

2. **Deploy Infrastructure**
   ```bash
   cd terraform/
   
   # Initialize Terraform
   terraform init
   
   # Plan deployment
   terraform plan -var="project_id=your-project-id" -var="database_password=secure-password"
   
   # Apply infrastructure
   terraform apply -var="project_id=your-project-id" -var="database_password=secure-password"
   ```

3. **Set up CI/CD Secrets**
   In your GitHub repository, add these secrets:
   - `GCP_SA_KEY`: Service account JSON key
   - `DATABASE_URL`: PostgreSQL connection string
   - `BASE_URL`: Your Cloud Run service URL

### CI/CD Pipeline

The GitHub Actions workflow automatically:
1. **Lints** code with flake8, black, and isort
2. **Tests** the application with pytest
3. **Builds** and pushes Docker images
4. **Deploys** to Cloud Run on main branch

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Database connection string | `sqlite:///./urls.db` |
| `BASE_URL` | Base URL for shortened links | `http://localhost:8000` |

## 📊 Monitoring & Observability

### Cloud Monitoring Features
- **Uptime Checks**: Monitors service health every 5 minutes
- **Error Rate Alerts**: Triggers when error rate exceeds 5%
- **Resource Monitoring**: Tracks CPU, memory, and request metrics
- **Log Aggregation**: Centralized logging with Cloud Logging

### Application Metrics
- Request latency and throughput
- Database connection health
- WebSocket connection counts
- Short URL creation and access rates

## 🔧 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client/Web    │────│  Load Balancer  │────│   Cloud Run     │
│   Browser       │    │                 │    │   (FastAPI)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐             │
                       │  Secret Manager │─────────────┤
                       │  (DB Creds)     │             │
                       └─────────────────┘             │
                                                       │
┌─────────────────┐    ┌─────────────────┐    ┌───────▼─────────┐
│  Monitoring &   │────│   Cloud SQL     │────│   Database      │
│  Alerting       │    │  (PostgreSQL)   │    │   Connection    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Components
- **FastAPI**: High-performance web framework
- **SQLAlchemy**: Database ORM with connection pooling
- **WebSocket**: Real-time communication
- **Cloud Run**: Serverless container platform
- **Cloud SQL**: Managed PostgreSQL database
- **Secret Manager**: Secure credential storage

## 🔒 Security

### Implemented Security Measures
- **Non-root container user** for reduced attack surface
- **IAM roles** with least privilege principle
- **Secret Manager** for sensitive data
- **HTTPS enforcement** in production
- **SQL injection protection** via ORM
- **Input validation** with Pydantic models

### Security Best Practices
- Database credentials stored in Secret Manager
- Service account with minimal required permissions
- Container security scanning in CI/CD
- HTTPS-only communication in production

## 🚧 Development

### Project Structure
```
├── main.py                 # Main FastAPI application
├── requirements.txt        # Python dependencies
├── Dockerfile             # Container configuration
├── test_main.py           # Unit tests
├── websocket_client.html  # HTML WebSocket client
├── websocket_client.py    # CLI WebSocket client
├── .github/
│   └── workflows/
│       └── ci-cd.yml      # GitHub Actions pipeline
├── terraform/
│   └── main.tf            # Infrastructure as code
└── README.md              # This file
```

### Code Quality Tools
- **Black**: Code formatting
- **isort**: Import sorting
- **flake8**: Linting
- **pytest**: Testing framework

### Development Workflow
1. Create feature branch
2. Write tests for new functionality
3. Implement feature
4. Run tests and linters locally
5. Create pull request
6. CI/CD pipeline runs automatically
7. Merge to main triggers deployment

## ⏱️ Time Breakdown

**Total Time: ~25 hours**

- **Backend Development** (8 hours)
  - FastAPI application setup: 2 hours
  - Database models and API endpoints: 3 hours
  - WebSocket implementation: 2 hours
  - Error handling and validation: 1 hour

- **Testing** (4 hours)
  - Unit tests for API endpoints: 2 hours
  - WebSocket testing: 1 hour
  - Integration tests: 1 hour

- **Containerization** (2 hours)
  - Dockerfile optimization: 1 hour
  - Docker security hardening: 1 hour

- **CI/CD Pipeline** (4 hours)
  - GitHub Actions setup: 2 hours
  - Testing and linting integration: 1 hour
  - Deployment automation: 1 hour

- **Infrastructure** (5 hours)
  - Terraform configuration: 3 hours
  - Cloud Run deployment: 1 hour
  - Monitoring and alerting setup: 1 hour

- **Documentation & Clients** (2 hours)
  - WebSocket client examples: 1 hour
  - README and documentation: 1 hour

## 🔄 Trade-offs & Decisions

### Technology Choices
- **FastAPI over Django**: Better performance for API-first applications, built-in async support, automatic API documentation
- **SQLAlchemy over raw SQL**: ORM provides better security, maintainability, and database abstraction
- **Cloud Run over GKE**: Serverless approach reduces operational overhead, automatic scaling, pay-per-use pricing
- **PostgreSQL over NoSQL**: ACID compliance important for URL mapping consistency, simpler data model

### Implementation Trade-offs
- **In-memory WebSocket management**: Simpler implementation but doesn't scale across multiple instances (production would use Redis/Pub-Sub)
- **SQLite default for development**: Easy setup but requires PostgreSQL for production
- **Basic short code generation**: Random generation vs. sequential/custom algorithms - chose random for simplicity
- **Stateless design**: No user authentication to keep scope manageable, but production would need auth

### Shortcuts Taken
- **No rate limiting**: Production should implement rate limiting to prevent abuse
- **Basic error handling**: Could be more granular with specific error codes and user-friendly messages
- **No caching layer**: Redis caching would improve performance for frequently accessed URLs
- **Simplified monitoring**: Production would benefit from more detailed metrics and custom dashboards

## 🚀 Production Considerations

### Scalability Improvements
- **Redis for WebSocket state**: Scale WebSocket connections across multiple instances
- **CDN integration**: Cache redirects for better global performance
- **Database read replicas**: Distribute read traffic for analytics
- **Connection pooling**: Optimize database connections under high load

### Additional Features for Production
- **Custom short codes**: Allow users to specify custom short codes
- **Expiration dates**: Set TTL for short URLs
- **Bulk operations**: Create/manage multiple URLs at once
- **Admin dashboard**: Web interface for URL management
- **API rate limiting**: Protect against abuse
- **Advanced analytics**: Click tracking, geographic data, referrer information

## 🐛 Known Issues & Limitations

- WebSocket connections don't persist across service restarts
- No authentication/authorization system
- SQLite limitations for high concurrent writes
- Basic error messages could be more user-friendly
- No input sanitization beyond URL validation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Install development dependencies
pip install -r requirements.txt
pip install black isort flake8 pytest-cov

# Set up pre-commit hooks
pre-commit install

# Run tests before committing
pytest --cov=main
```

## 📚 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [WebSocket API Documentation](https://websockets.readthedocs.io/)

## 📞 Support

If you encounter any issues or have questions:
1. Check the [Issues](../../issues) page for existing problems
2. Review the logs: `docker logs <container_id>`
3. Verify environment variables and configuration
4. Check Google Cloud Console for deployment issues

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ using FastAPI, Docker, and Google Cloud Platform**