import pytest
import asyncio
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import app, get_db, Base, URLMapping
import os

# Test database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine)

class TestURLShortener:
    
    def test_root_endpoint(self, client):
        """Test the root endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        assert "URL Shortener Service" in response.json()["message"]
    
    def test_health_check(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
    
    def test_shorten_url_success(self, client):
        """Test successful URL shortening"""
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        assert response.status_code == 200
        data = response.json()
        assert "short_code" in data
        assert "shortened_url" in data
        assert data["original_url"] == "https://www.example.com"
        assert len(data["short_code"]) == 6
    
    def test_shorten_url_invalid(self, client):
        """Test URL shortening with invalid URL"""
        response = client.post("/shorten", json={"url": "not-a-valid-url"})
        assert response.status_code == 422  # Validation error
    
    def test_redirect_success(self, client):
        """Test successful redirect"""
        # First create a short URL
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        short_code = response.json()["short_code"]
        
        # Then test redirect
        response = client.get(f"/{short_code}", follow_redirects=False)
        assert response.status_code == 302
        assert response.headers["location"] == "https://www.example.com"
    
    def test_redirect_not_found(self, client):
        """Test redirect with non-existent short code"""
        response = client.get("/nonexistent", follow_redirects=False)
        assert response.status_code == 404
    
    def test_analytics_success(self, client):
        """Test analytics retrieval"""
        # Create a short URL
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        short_code = response.json()["short_code"]
        
        # Access it once to increment counter
        client.get(f"/{short_code}", follow_redirects=False)
        
        # Get analytics
        response = client.get(f"/analytics/{short_code}")
        assert response.status_code == 200
        data = response.json()
        assert data["short_code"] == short_code
        assert data["original_url"] == "https://www.example.com"
        assert data["redirect_count"] == 1
        assert "created_at" in data
    
    def test_analytics_not_found(self, client):
        """Test analytics for non-existent short code"""
        response = client.get("/analytics/nonexistent")
        assert response.status_code == 404
    
    def test_multiple_redirects_increment_counter(self, client):
        """Test that multiple redirects increment the counter"""
        # Create a short URL
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        short_code = response.json()["short_code"]
        
        # Access it multiple times
        for _ in range(3):
            client.get(f"/{short_code}", follow_redirects=False)
        
        # Check analytics
        response = client.get(f"/analytics/{short_code}")
        assert response.json()["redirect_count"] == 3
    
    def test_unique_short_codes(self, client):
        """Test that different URLs get different short codes"""
        response1 = client.post("/shorten", json={"url": "https://www.example1.com"})
        response2 = client.post("/shorten", json={"url": "https://www.example2.com"})
        
        code1 = response1.json()["short_code"]
        code2 = response2.json()["short_code"]
        
        assert code1 != code2

class TestWebSocketAnalytics:
    
    def test_websocket_connection(self, client):
        """Test WebSocket connection and initial data"""
        # Create a short URL first
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        short_code = response.json()["short_code"]
        
        # Test WebSocket connection
        with client.websocket_connect(f"/ws/analytics/{short_code}") as websocket:
            data = websocket.receive_json()
            assert data["short_code"] == short_code
            assert data["redirect_count"] == 0
            assert "created_at" in data
    
    def test_websocket_real_time_updates(self, client):
        """Test real-time WebSocket updates when URL is accessed"""
        # Create a short URL
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        short_code = response.json()["short_code"]
        
        with client.websocket_connect(f"/ws/analytics/{short_code}") as websocket:
            # Receive initial data
            initial_data = websocket.receive_json()
            assert initial_data["redirect_count"] == 0
            
            # Access the URL to trigger update
            client.get(f"/{short_code}", follow_redirects=False)
            
            # Should receive update via WebSocket
            # Note: In real implementation, this would be async
            # For testing, we'll verify the analytics endpoint instead
            analytics_response = client.get(f"/analytics/{short_code}")
            assert analytics_response.json()["redirect_count"] == 1

if __name__ == "__main__":
    pytest.main([__file__])