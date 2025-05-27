#!/usr/bin/env python3
"""
WebSocket CLI Client for URL Shortener Analytics
Usage: python websocket_client.py <short_code> [--url <base_url>]
"""

import asyncio
import websockets
import json
import argparse
import sys
from datetime import datetime

class AnalyticsClient:
    def __init__(self, base_url: str = "ws://localhost:8000"):
        self.base_url = base_url
        self.websocket = None
        self.connected = False
    
    async def connect(self, short_code: str):
        """Connect to WebSocket and listen for analytics updates"""
        url = f"{self.base_url}/ws/analytics/{short_code}"
        
        try:
            print(f"Connecting to {url}...")
            self.websocket = await websockets.connect(url)
            self.connected = True
            print(f"✅ Connected to real-time analytics for short code: {short_code}")
            print("Listening for updates... (Press Ctrl+C to disconnect)\n")
            
            async for message in self.websocket:
                await self.handle_message(message)
                
        except websockets.exceptions.ConnectionClosed:
            print("🔌 Connection closed")
            self.connected = False
        except KeyboardInterrupt:
            print("\n🛑 Disconnecting...")
            await self.disconnect()
        except Exception as e:
            print(f"❌ Error: {e}")
            self.connected = False
    
    async def handle_message(self, message: str):
        """Handle incoming WebSocket messages"""
        try:
            data = json.loads(message)
            
            if data.get("type") == "heartbeat":
                print("💓 Heartbeat received")
                return
            
            # Display analytics data
            self.display_analytics(data)
            
        except json.JSONDecodeError:
            print(f"⚠️  Invalid JSON received: {message}")
    
    def display_analytics(self, data: dict):
        """Display analytics data in a formatted way"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        print("=" * 50)
        print(f"📊 Analytics Update - {timestamp}")
        print("=" * 50)
        print(f"Short Code: {data.get('short_code', 'N/A')}")
        print(f"Redirect Count: {data.get('redirect_count', 0)}")
        
        if 'created_at' in data:
            created_at = datetime.fromisoformat(data['created_at'].replace('Z', '+00:00'))
            print(f"Created: {created_at.strftime('%Y-%m-%d %H:%M:%S')}")
        
        if 'timestamp' in data:
            update_time = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
            print(f"Last Update: {update_time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        print("-" * 50)
        print()
    
    async def disconnect(self):
        """Disconnect from WebSocket"""
        if self.websocket and self.connected:
            await self.websocket.close()
            self.connected = False
            print("👋 Disconnected successfully")

async def create_short_url(base_url: str, long_url: str):
    """Create a short URL using the API"""
    import aiohttp
    
    api_url = base_url.replace('ws://', 'http://').replace('wss://', 'https://')
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.post(
                f"{api_url}/shorten",
                json={"url": long_url}
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return data
                else:
                    print(f"❌ Error creating short URL: HTTP {response.status}")
                    return None
        except Exception as e:
            print(f"❌ Error creating short URL: {e}")
            return None

async def get_analytics(base_url: str, short_code: str):
    """Get current analytics for a short code"""
    import aiohttp
    
    api_url = base_url.replace('ws://', 'http://').replace('wss://', 'https://')
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{api_url}/analytics/{short_code}") as response:
                if response.status == 200:
                    data = await response.json()
                    return data
                else:
                    print(f"❌ Error fetching analytics: HTTP {response.status}")
                    return None
        except Exception as e:
            print(f"❌ Error fetching analytics: {e}")
            return None

def main():
    parser = argparse.ArgumentParser(description="WebSocket CLI Client for URL Shortener Analytics")
    parser.add_argument("short_code", help="Short code to monitor")
    parser.add_argument("--url", default="ws://localhost:8000", help="Base WebSocket URL")
    parser.add_argument("--create", help="Create a short URL first from this long URL")
    parser.add_argument("--current", action="store_true", help="Show current analytics before connecting to WebSocket")
    
    args = parser.parse_args()
    
    async def run():
        client = AnalyticsClient(args.url)
        
        # Create short URL if requested
        if args.create:
            print(f"Creating short URL for: {args.create}")
            result = await create_short_url(args.url, args.create)
            if result:
                print(f"✅ Created short URL:")
                print(f"   Short Code: {result['short_code']}")
                print(f"   Shortened URL: {result['shortened_url']}")
                print(f"   Original URL: {result['original_url']}")
                print()
                
                # Update short_code to the newly created one
                args.short_code = result['short_code']
            else:
                return
        
        # Show current analytics if requested
        if args.current:
            print(f"Fetching current analytics for: {args.short_code}")
            analytics = await get_analytics(args.url, args.short_code)
            if analytics:
                client.display_analytics(analytics)
            else:
                print("❌ Could not fetch current analytics")
                return
        
        # Connect to WebSocket for real-time updates
        await client.connect(args.short_code)
    
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()