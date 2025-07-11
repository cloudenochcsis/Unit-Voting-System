import redis
import json
import os
from datetime import datetime

# Sample soldier data for testing
SAMPLE_SOLDIERS = [
    {"soldier_id": "12345", "rank": "SGT", "unit": "Alpha Company"},
    {"soldier_id": "23456", "rank": "CPL", "unit": "Bravo Company"},
    {"soldier_id": "34567", "rank": "SPC", "unit": "Charlie Company"},
    {"soldier_id": "45678", "rank": "PFC", "unit": "Delta Company"},
    {"soldier_id": "56789", "rank": "SSG", "unit": "HQ Company"}
]

def init_redis():
    """Initialize Redis with sample data for testing."""
    redis_host = os.environ.get('REDIS_HOST', 'localhost')
    redis_port = int(os.environ.get('REDIS_PORT', 6379))
    
    try:
        r = redis.Redis(host=redis_host, port=redis_port)
        
        # Clear existing data
        r.flushall()
        
        # Add sample soldiers
        for soldier in SAMPLE_SOLDIERS:
            r.set(f"soldier:{soldier['soldier_id']}:info", json.dumps(soldier))
            # Initially no one has voted
            r.delete(f"soldier:{soldier['soldier_id']}:voted")
        
        print(f"Redis initialized with {len(SAMPLE_SOLDIERS)} sample soldiers")
        return True
    except Exception as e:
        print(f"Error initializing Redis: {e}")
        return False

if __name__ == "__main__":
    init_redis()
