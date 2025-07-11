#!/usr/bin/env python3
"""
Seed Data Script for Military Unit Voting System
Creates sample soldier accounts with passwords for testing
"""

import redis
import json
import os
import random
import logging
from passlib.hash import bcrypt_sha256
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Redis connection
redis_host = os.environ.get('REDIS_HOST', 'localhost')
redis_port = int(os.environ.get('REDIS_PORT', 6379))

# Sample data
RANKS = ['PVT', 'SPC', 'SGT', 'SSG', 'CPT', 'MAJ']
UNITS = ['Alpha Company', 'Bravo Company', 'Charlie Company', 'HQ']
FIRST_NAMES = ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles', 
               'Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen']
LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor',
              'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Martinez', 'Robinson']

def generate_soldier_id(rank, index):
    """Generate a realistic soldier ID based on rank and index"""
    if rank in ['CPT', 'MAJ']:
        # Officer format: O + 5 digits
        return f"O{10000 + index}"
    else:
        # Enlisted format: E + 5 digits
        return f"E{10000 + index}"

def create_test_soldiers(num_soldiers=20):
    """Create test soldier accounts in Redis"""
    try:
        # Connect to Redis
        redis_client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
        redis_client.ping()  # Test connection
        logger.info(f"Connected to Redis at {redis_host}:{redis_port}")
        
        # Create soldiers
        created_count = 0
        for i in range(num_soldiers):
            # Generate soldier data
            rank = random.choice(RANKS)
            unit = random.choice(UNITS)
            first_name = random.choice(FIRST_NAMES)
            last_name = random.choice(LAST_NAMES)
            name = f"{first_name} {last_name}"
            
            # Generate soldier ID
            soldier_id = generate_soldier_id(rank, i)
            
            # Set password (simple for testing)
            password = f"password_{soldier_id.lower()}"
            password_hash = bcrypt_sha256.hash(password)
            
            # Create soldier data
            soldier_data = {
                'rank': rank,
                'unit': unit,
                'name': name,
                'password_hash': password_hash,
                'registration_date': datetime.now().isoformat()
            }
            
            # Store in Redis
            key = f'soldier:{soldier_id}:info'
            redis_client.set(key, json.dumps(soldier_data))
            created_count += 1
            
            logger.info(f"Created soldier: {soldier_id} - {rank} {name} ({unit}) with password: {password}")
        
        logger.info(f"Successfully created {created_count} test soldiers")
        
        # Print summary for easy reference
        print("\n" + "="*50)
        print("MILITARY UNIT VOTING SYSTEM - TEST ACCOUNTS")
        print("="*50)
        print("The following test accounts have been created:")
        
        # Get all soldier keys
        soldier_keys = redis_client.keys('soldier:*:info')
        for key in sorted(soldier_keys):
            soldier_id = key.split(':')[1]
            data = json.loads(redis_client.get(key))
            print(f"ID: {soldier_id} | Rank: {data['rank']} | Name: {data['name']} | Password: password_{soldier_id.lower()}")
        
        print("="*50)
        print("Use these accounts to test the voting system")
        print("="*50)
        
    except redis.ConnectionError as e:
        logger.error(f"Redis connection error: {e}")
    except Exception as e:
        logger.error(f"Error creating test data: {e}")

if __name__ == "__main__":
    create_test_soldiers()
    print("Seed data script completed.")
