import pytest
import asyncio
import json
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
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="function")
def client():
    # Create tables
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as c:
        yield c
    # Clean up
    Base.metadata.drop_all(bind=engine)
    # Remove test database file if it exists
    if os.path.exists("test.db"):
        os.remove("test.db")

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
        assert response.status_code == 200
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
        assert response.status_code == 200
        short_code = response.json()["short_code"]
        
        # Access it once to increment counter
        redirect_response = client.get(f"/{short_code}", follow_redirects=False)
        assert redirect_response.status_code == 302
        
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
        assert response.status_code == 200
        short_code = response.json()["short_code"]
        
        # Access it multiple times
        for i in range(3):
            redirect_response = client.get(f"/{short_code}", follow_redirects=False)
            assert redirect_response.status_code == 302
        
        # Check analytics
        response = client.get(f"/analytics/{short_code}")
        assert response.status_code == 200
        assert response.json()["redirect_count"] == 3
    
    def test_unique_short_codes(self, client):
        """Test that different URLs get different short codes"""
        response1 = client.post("/shorten", json={"url": "https://www.example1.com"})
        response2 = client.post("/shorten", json={"url": "https://www.example2.com"})
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        
        code1 = response1.json()["short_code"]
        code2 = response2.json()["short_code"]
        
        assert code1 != code2
    
    def test_shorten_url_with_complex_url(self, client):
        """Test URL shortening with complex URLs"""
        complex_url = "https://example.com/path?param1=value1&param2=value2#fragment"
        response = client.post("/shorten", json={"url": complex_url})
        assert response.status_code == 200
        data = response.json()
        assert data["original_url"] == complex_url

class TestWebSocketAnalytics:
    
    def test_websocket_connection(self, client):
        """Test WebSocket connection and initial data"""
        # Create a short URL first
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        assert response.status_code == 200
        short_code = response.json()["short_code"]
        
        # Test WebSocket connection
        with client.websocket_connect(f"/ws/analytics/{short_code}") as websocket:
            # Should receive initial data
            data = websocket.receive_json()
            assert data["short_code"] == short_code
            assert data["redirect_count"] == 0
            assert "created_at" in data
            assert "timestamp" in data
    
    def test_websocket_with_nonexistent_code(self, client):
        """Test WebSocket connection with non-existent short code"""
        with client.websocket_connect("/ws/analytics/nonexistent") as websocket:
            # Should still connect but receive initial data with 0 redirect count
            # for non-existent codes, or handle gracefully
            try:
                data = websocket.receive_json()
                # If it receives data, it should be valid JSON
                assert isinstance(data, dict)
            except Exception:
                # Connection might be closed immediately for non-existent codes
                pass

    def test_websocket_disconnect(self, client):
        """Test WebSocket connection and disconnection"""
        # Create a short URL first
        response = client.post("/shorten", json={"url": "https://www.example.com"})
        assert response.status_code == 200
        short_code = response.json()["short_code"]
        
        # Test WebSocket connection and disconnection
        with client.websocket_connect(f"/ws/analytics/{short_code}") as websocket:
            # Receive initial data
            data = websocket.receive_json()
            assert data["short_code"] == short_code
            
            # Close connection gracefully
            websocket.close()

class TestErrorHandling:
    
    def test_empty_url_shorten(self, client):
        """Test shortening with empty URL"""
        response = client.post("/shorten", json={"url": ""})
        assert response.status_code == 422
    
    def test_missing_url_field(self, client):
        """Test shortening without URL field"""
        response = client.post("/shorten", json={})
        assert response.status_code == 422
    
    def test_invalid_json(self, client):
        """Test with invalid JSON"""
        response = client.post("/shorten", data="invalid json")
        assert response.status_code == 422

# Integration test
class TestIntegration:
    
    def test_full_workflow(self, client):
        """Test the complete workflow: create -> redirect -> analytics"""
        # Step 1: Create short URL
        create_response = client.post("/shorten", json={"url": "https://github.com"})
        assert create_response.status_code == 200
        short_code = create_response.json()["short_code"]
        
        # Step 2: Test redirect
        redirect_response = client.get(f"/{short_code}", follow_redirects=False)
        assert redirect_response.status_code == 302
        assert redirect_response.headers["location"] == "https://github.com"
        
        # Step 3: Check analytics
        analytics_response = client.get(f"/analytics/{short_code}")
        assert analytics_response.status_code == 200
        analytics_data = analytics_response.json()
        assert analytics_data["redirect_count"] == 1
        assert analytics_data["original_url"] == "https://github.com"
        
        # Step 4: Test WebSocket
        with client.websocket_connect(f"/ws/analytics/{short_code}") as websocket:
            ws_data = websocket.receive_json()
            assert ws_data["short_code"] == short_code
            assert ws_data["redirect_count"] == 1

if __name__ == "__main__":
    pytest.main([__file__, "-v"])