from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl
from sqlalchemy import create_engine, Column, String, DateTime, Integer
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from datetime import datetime, timezone
import hashlib
import string
import random
import os
import json
import asyncio
from typing import Dict, List
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="URL Shortener Service", version="1.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./urls.db")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, short_code: str):
        await websocket.accept()
        if short_code not in self.active_connections:
            self.active_connections[short_code] = []
        self.active_connections[short_code].append(websocket)
        logger.info(f"WebSocket connected for short_code: {short_code}")

    def disconnect(self, websocket: WebSocket, short_code: str):
        if short_code in self.active_connections:
            if websocket in self.active_connections[short_code]:
                self.active_connections[short_code].remove(websocket)
            if not self.active_connections[short_code]:
                del self.active_connections[short_code]
        logger.info(f"WebSocket disconnected for short_code: {short_code}")

    async def send_analytics_update(self, short_code: str, analytics_data: dict):
        if short_code in self.active_connections:
            disconnected = []
            for connection in self.active_connections[short_code]:
                try:
                    await connection.send_text(json.dumps(analytics_data))
                except Exception as e:
                    logger.error(f"WebSocket send error: {e}")
                    disconnected.append(connection)
            
            # Clean up disconnected clients
            for conn in disconnected:
                self.disconnect(conn, short_code)

manager = ConnectionManager()

# Database Models
class URLMapping(Base):
    __tablename__ = "url_mappings"
    
    short_code = Column(String(10), primary_key=True, index=True)
    original_url = Column(String(2048), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    redirect_count = Column(Integer, default=0)

# Create tables
Base.metadata.create_all(bind=engine)

# Pydantic models
class URLShortenRequest(BaseModel):
    url: HttpUrl

class URLShortenResponse(BaseModel):
    short_code: str
    shortened_url: str
    original_url: str

class AnalyticsResponse(BaseModel):
    short_code: str
    original_url: str
    redirect_count: int
    created_at: datetime

# Utility functions
def generate_short_code(length: int = 6) -> str:
    """Generate a random short code"""
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# IMPORTANT: Static routes MUST come before dynamic routes!

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "URL Shortener Service",
        "version": "1.0.0",
        "endpoints": {
            "POST /shorten": "Create a shortened URL",
            "GET /{short_code}": "Redirect to original URL",
            "GET /analytics/{short_code}": "Get analytics for short URL",
            "WS /ws/analytics/{short_code}": "Real-time analytics updates"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy", 
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

@app.post("/shorten", response_model=URLShortenResponse)
async def shorten_url(request: URLShortenRequest):
    """Create a shortened URL"""
    db = SessionLocal()
    try:
        # Generate unique short code
        max_attempts = 10
        attempts = 0
        short_code: str = ""
        
        while attempts < max_attempts:
            short_code = generate_short_code()
            existing = db.query(URLMapping).filter(URLMapping.short_code == short_code).first()
            if not existing:
                break
            attempts += 1
        
        if attempts >= max_attempts or not short_code:
            raise HTTPException(status_code=500, detail="Unable to generate unique short code")
        
        # Create new URL mapping
        url_mapping = URLMapping(
            short_code=short_code,
            original_url=str(request.url)
        )
        db.add(url_mapping)
        db.commit()
        
        base_url = os.getenv("BASE_URL", "http://localhost:8000")
        shortened_url = f"{base_url}/{short_code}"
        
        logger.info(f"Created short URL: {short_code} -> {request.url}")
        
        return URLShortenResponse(
            short_code=short_code,
            shortened_url=shortened_url,
            original_url=str(request.url)
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating short URL: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        db.close()

@app.get("/analytics/{short_code}", response_model=AnalyticsResponse)
async def get_analytics(short_code: str):
    """Get analytics for a short URL"""
    db = SessionLocal()
    try:
        url_mapping = db.query(URLMapping).filter(URLMapping.short_code == short_code).first()
        
        if not url_mapping:
            raise HTTPException(status_code=404, detail="Short URL not found")
        
        return AnalyticsResponse(
            short_code=url_mapping.short_code,  # type: ignore
            original_url=url_mapping.original_url,  # type: ignore
            redirect_count=url_mapping.redirect_count,  # type: ignore
            created_at=url_mapping.created_at  # type: ignore
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching analytics: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        db.close()

@app.websocket("/ws/analytics/{short_code}")
async def websocket_analytics(websocket: WebSocket, short_code: str):
    """WebSocket endpoint for real-time analytics updates"""
    await manager.connect(websocket, short_code)
    try:
        # Send initial analytics data
        db = SessionLocal()
        try:
            url_mapping = db.query(URLMapping).filter(URLMapping.short_code == short_code).first()
            if url_mapping:
                initial_data = {
                    "short_code": short_code,
                    "redirect_count": url_mapping.redirect_count,  # type: ignore
                    "created_at": url_mapping.created_at.isoformat(),  # type: ignore
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
                await websocket.send_text(json.dumps(initial_data))
        finally:
            db.close()
        
        # Keep connection alive with heartbeat
        while True:
            await asyncio.sleep(30)  # Send heartbeat every 30 seconds
            await websocket.send_text(json.dumps({
                "type": "heartbeat", 
                "timestamp": datetime.now(timezone.utc).isoformat()
            }))
    
    except WebSocketDisconnect:
        manager.disconnect(websocket, short_code)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket, short_code)

# IMPORTANT: Dynamic route MUST come last!
@app.get("/{short_code}")
async def redirect_to_original(short_code: str):
    """Redirect to the original URL and update analytics"""
    db = SessionLocal()
    try:
        url_mapping = db.query(URLMapping).filter(URLMapping.short_code == short_code).first()
        
        if not url_mapping:
            raise HTTPException(status_code=404, detail="Short URL not found")
        
        # Update redirect count
        url_mapping.redirect_count += 1  # type: ignore
        db.commit()
        
        # Send real-time analytics update via WebSocket
        analytics_data = {
            "short_code": short_code,
            "redirect_count": url_mapping.redirect_count,  # type: ignore
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        await manager.send_analytics_update(short_code, analytics_data)
        
        logger.info(f"Redirecting {short_code} to {url_mapping.original_url}")
        
        return RedirectResponse(url=url_mapping.original_url, status_code=302)  # type: ignore
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error redirecting: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        db.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)