# URL Shortener Service

A scalable URL shortener service built with FastAPI, featuring real-time analytics, containerization with Docker, CI/CD pipeline with GitHub Actions, and deployment to Google Cloud Run.

## Live Deployment

**Service URL**: https://url-shortener-939986137088.us-central1.run.app

- API Documentation: https://url-shortener-939986137088.us-central1.run.app/docs
- Health Check: https://url-shortener-939986137088.us-central1.run.app/health

## Features

- RESTful API for URL shortening and analytics
- Real-time analytics via WebSocket connections
- Scalable containerized deployment
- Automated CI/CD pipeline
- Production-ready cloud infrastructure
- Comprehensive test coverage
- Security best practices

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/shorten` | Create a shortened URL |
| `GET` | `/{short_code}` | Redirect to original URL |
| `GET` | `/analytics/{short_code}` | Get analytics for short URL |
| `WS` | `/ws/analytics/{short_code}` | Real-time analytics updates |
| `GET` | `/health` | Health check endpoint |

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run the application
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Access the service
# API: http://localhost:8000
# Documentation: http://localhost:8000/docs
```

### Using Docker

```bash
# Build the image
docker build -t url-shortener .

# Run the container
docker run -p 8000:8000 url-shortener
```

### Running Tests

```bash
# Execute test suite
python windows_test.py

# Run with coverage
pytest --cov=main --cov-report=html
```

## Usage Examples

### Create Short URL

```bash
curl -X POST "https://url-shortener-939986137088.us-central1.run.app/shorten" \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.example.com"}'
```

Response:
```json
{
  "short_code": "abc123",
  "shortened_url": "https://url-shortener-939986137088.us-central1.run.app/abc123",
  "original_url": "https://www.example.com"
}
```

### Access Short URL

```bash
curl -L "https://url-shortener-939986137088.us-central1.run.app/abc123"
# Redirects to https://www.example.com
```

### Get Analytics

```bash
curl "https://url-shortener-939986137088.us-central1.run.app/analytics/abc123"
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

```bash
# Using CLI client
python websocket_client.py abc123 --url wss://url-shortener-939986137088.us-central1.run.app

# Create and monitor new URL
python websocket_client.py new_code --create "https://example.com" --url wss://url-shortener-939986137088.us-central1.run.app
```

## Architecture

### System Design

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client/Web    │────│  Load Balancer  │────│   Cloud Run     │
│   Browser       │    │                 │    │   (FastAPI)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐             │
                       │   Database      │─────────────┤
                       │   (SQLite)      │             │
                       └─────────────────┘             │
                                                       │
┌─────────────────┐    ┌─────────────────┐    ┌───────▼─────────┐
│  Monitoring &   │────│  GitHub Actions │────│   Container     │
│  Logging        │    │     CI/CD       │    │   Registry      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Components

- **FastAPI**: High-performance web framework with automatic API documentation
- **SQLAlchemy**: Database ORM with connection pooling
- **WebSocket**: Real-time bidirectional communication
- **Cloud Run**: Serverless container platform with automatic scaling
- **Google Container Registry**: Container image storage
- **GitHub Actions**: Automated CI/CD pipeline

## CI/CD Pipeline

The automated pipeline includes:

1. **Code Quality**: Linting with flake8, formatting with black, import sorting with isort
2. **Testing**: Unit tests with pytest, coverage reporting
3. **Build**: Docker image creation and optimization
4. **Deploy**: Automated deployment to Google Cloud Run
5. **Verify**: Post-deployment health checks

### Pipeline Configuration

- **Trigger**: Push to main branch or pull request
- **Test Environment**: Ubuntu latest with Python 3.11
- **Container Registry**: Google Container Registry (GCR)
- **Deployment Target**: Google Cloud Run (us-central1)

## Infrastructure

### Google Cloud Platform Setup

- **Project ID**: url-shortener-20250527232607
- **Region**: us-central1
- **Compute**: Cloud Run (serverless containers)
- **Storage**: SQLite (lightweight, embedded database)
- **Networking**: HTTPS-only with automatic SSL

### Security Implementation

- **Container Security**: Non-root user execution
- **IAM**: Least-privilege service account permissions
- **Network**: HTTPS enforcement, no public database access
- **Authentication**: Service-to-service authentication with Google Cloud
- **Input Validation**: Pydantic models for request validation

### Scalability Configuration

- **Auto-scaling**: 0 to 10 instances based on demand
- **Resource Limits**: 512Mi memory, 1 CPU per instance
- **Concurrency**: 100 concurrent requests per instance
- **Timeout**: 300 seconds per request

## Development

### Project Structure

```
├── main.py                    # FastAPI application
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Container configuration
├── windows_test.py            # Test suite
├── websocket_client.html      # WebSocket browser client
├── websocket_client.py        # WebSocket CLI client
├── .github/workflows/ci-cd.yml # CI/CD pipeline
└── README.md                  # Documentation
```

### Code Quality Standards

- **Linting**: flake8 with extended ignore rules
- **Formatting**: black for consistent code style
- **Import Management**: isort for organized imports
- **Testing**: pytest with coverage reporting
- **Type Hints**: Python type annotations where applicable

### Development Workflow

1. Create feature branch from main
2. Implement functionality with tests
3. Run local quality checks and tests
4. Create pull request
5. Automated CI/CD pipeline validation
6. Code review and merge
7. Automatic deployment to production

## Testing

### Test Coverage

- **Unit Tests**: Core business logic validation
- **Integration Tests**: API endpoint testing
- **WebSocket Tests**: Real-time functionality validation
- **Error Handling**: Edge case and failure scenario testing

### Test Execution

```bash
# Run all tests
python windows_test.py

# Run specific test categories
pytest -k "test_shorten_url"

# Generate coverage report
pytest --cov=main --cov-report=html
```

## Time Investment

**Total Development Time: 9.5 hours**

| Component | Time Allocation |
|-----------|----------------|
| Backend Development | 3 hours |
| Testing Implementation | 3 hours |
| Containerization | 1 hours |
| CI/CD Pipeline | 1 hours |
| Infrastructure Setup | 1 hours |
| Documentation | 0.5 hours |

## Technical Decisions

### Framework Selection

**FastAPI over Django**: Chosen for superior API performance, built-in async support, automatic OpenAPI documentation, and modern Python features.

### Database Choice

**SQLite over PostgreSQL**: Selected for simplicity and deployment efficiency. Demonstrates all required functionality without database connection complexity. Production deployment would use Cloud SQL PostgreSQL.

### Deployment Strategy

**Cloud Run over GKE**: Serverless approach eliminates infrastructure management overhead, provides automatic scaling, and offers cost-effective pay-per-use pricing model.

### Container Registry

**Google Container Registry over Artifact Registry**: Established workflow with fewer permission complexities for initial deployment. Artifact Registry recommended for production environments.

## Production Considerations

### Scalability Enhancements

- **Database**: Migrate to Cloud SQL PostgreSQL with read replicas
- **Caching**: Implement Redis for frequently accessed URLs
- **CDN**: Add CloudFlare or Google CDN for global performance
- **Load Balancing**: Configure advanced load balancing strategies

### Security Improvements

- **Rate Limiting**: Implement API rate limiting and abuse prevention
- **Authentication**: Add user accounts and API key management
- **Monitoring**: Enhanced security monitoring and alerting
- **Audit Logging**: Comprehensive access and modification logging

### Operational Excellence

- **Monitoring**: Custom metrics, dashboards, and alerting
- **Backup Strategy**: Automated database backups and recovery procedures
- **Disaster Recovery**: Multi-region deployment and failover mechanisms
- **Performance Optimization**: Database indexing and query optimization

## Assignment Requirements Fulfillment

### Part 1: Service Implementation
- RESTful API with all specified endpoints
- Python with FastAPI framework
- Database integration with proper ORM
- Comprehensive unit testing
- Robust error handling for edge cases

### Part 2: Containerization
- Optimized Dockerfile with multi-stage builds
- Security-hardened container (non-root user)
- Health check implementation
- Efficient layer caching

### Part 3: CI/CD Pipeline
- GitHub Actions workflow automation
- Code quality enforcement (linting, formatting)
- Automated testing execution
- Container building and registry pushing

### Part 4: Infrastructure & Security
- Google Cloud Run deployment
- IAM configuration with least-privilege principles
- Service-to-service authentication
- Environment variable management
- Monitoring and logging integration

### Part 5: WebSocket Extension (Bonus)
- Real-time analytics implementation
- Multiple concurrent connection support
- Client-side examples (CLI and web)
- Connection lifecycle management
- Heartbeat and cleanup mechanisms

## Support and Maintenance

### Monitoring

- **Health Checks**: Automated endpoint monitoring
- **Performance Metrics**: Response time and throughput tracking
- **Error Tracking**: Exception monitoring and alerting
- **Resource Usage**: CPU, memory, and scaling metrics

### Troubleshooting

Common issues and solutions documented in operational runbooks. Comprehensive logging enables rapid issue identification and resolution.

### Updates and Deployment

Rolling deployments ensure zero-downtime updates. Feature flags enable safe rollout of new functionality.

---

**Built with Python, FastAPI, Docker, and Google Cloud Platform**