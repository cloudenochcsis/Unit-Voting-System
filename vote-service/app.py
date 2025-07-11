from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
import redis
import os
import json
import uuid
import logging
from datetime import datetime
from functools import wraps
import time
from passlib.hash import bcrypt_sha256
from itsdangerous import BadSignature
import psycopg2
from psycopg2 import pool

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__, static_url_path='/static', static_folder='static')
app.secret_key = os.environ.get('SECRET_KEY', 'military_unit_voting_system_secret')
app.config['SESSION_TYPE'] = 'filesystem'

# Redis connection
redis_host = os.environ.get('REDIS_HOST', 'localhost')
redis_port = int(os.environ.get('REDIS_PORT', 6379))

# PostgreSQL connection
db_host = os.environ.get('DB_HOST', 'localhost')
db_port = int(os.environ.get('DB_PORT', 5432))
db_name = os.environ.get('DB_NAME', 'votingdb')
db_user = os.environ.get('DB_USER', 'postgres')
db_password = os.environ.get('DB_PASSWORD', 'postgres')

# Attempt to connect to Redis with retry logic
def get_redis_connection():
    retry_count = 0
    max_retries = 5
    
    while retry_count < max_retries:
        try:
            return redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
        except redis.ConnectionError as e:
            retry_count += 1
            logger.warning(f'Redis connection attempt {retry_count} failed: {e}')
            if retry_count >= max_retries:
                logger.error('Maximum Redis connection attempts reached')
                raise
            time.sleep(1)  # Wait before retrying

# Mock Redis implementation for testing without Redis server
class MockRedis:
    def __init__(self):
        self.data = {}
        self.lists = {}
        logger.info('Using MockRedis for testing')
    
    def ping(self):
        return True
    
    def get(self, key):
        return self.data.get(key)
    
    def set(self, key, value):
        self.data[key] = value
        return True
    
    def exists(self, key):
        return key in self.data
    
    def rpush(self, key, value):
        if key not in self.lists:
            self.lists[key] = []
        self.lists[key].append(value)
        return len(self.lists[key])
    
    def llen(self, key):
        return len(self.lists.get(key, []))
    
    def keys(self, pattern):
        import fnmatch
        return [k for k in self.data.keys() if fnmatch.fnmatch(k, pattern)]
    
    def pipeline(self):
        return self
    
    def execute(self):
        return [True, True]

# PostgreSQL connection pool and helper functions
def get_db_connection_pool():
    retry_count = 0
    max_retries = 5
    
    while retry_count < max_retries:
        try:
            return pool.SimpleConnectionPool(
                minconn=1,
                maxconn=10,
                host=db_host,
                port=db_port,
                database=db_name,
                user=db_user,
                password=db_password
            )
        except psycopg2.Error as e:
            retry_count += 1
            logger.warning(f'PostgreSQL connection attempt {retry_count} failed: {e}')
            if retry_count >= max_retries:
                logger.error('Maximum PostgreSQL connection attempts reached')
                raise
            time.sleep(1)  # Wait before retrying

# Create a mock DB connection for testing
class MockDBConnection:
    def __init__(self):
        self.soldiers = {}
        logger.info('Using MockDBConnection for testing')
        
    def cursor(self):
        return MockDBCursor(self)
    
    def commit(self):
        pass
    
    def close(self):
        pass

class MockDBCursor:
    def __init__(self, conn):
        self.conn = conn
        self.query = None
        self.params = None
        
    def execute(self, query, params=None):
        self.query = query
        self.params = params
        
    def fetchone(self):
        if self.query and 'SELECT' in self.query.upper() and 'soldiers' in self.query.lower():
            soldier_id = self.params[0] if self.params else None
            if soldier_id in self.conn.soldiers:
                return [self.conn.soldiers[soldier_id]]
        return None
    
    def close(self):
        pass

# Function to get a database connection from the pool
def get_db_connection():
    try:
        return db_pool.getconn()
    except Exception as e:
        logger.error(f'Error getting DB connection: {e}')
        return MockDBConnection()

# Function to save a soldier to the database
def save_soldier_to_db(soldier_id, rank, unit, password_hash):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if soldier already exists
        cursor.execute("SELECT soldier_id FROM soldiers WHERE soldier_id = %s", (soldier_id,))
        existing = cursor.fetchone()
        
        if existing:
            # Update existing soldier
            cursor.execute(
                "UPDATE soldiers SET rank = %s, unit = %s WHERE soldier_id = %s",
                (rank, unit, soldier_id)
            )
            # Store password hash in Redis (not in PostgreSQL for this demo)
            redis_client.set(f'soldier:{soldier_id}:password', password_hash)
        else:
            # Insert new soldier
            cursor.execute(
                "INSERT INTO soldiers (soldier_id, rank, unit, has_voted) VALUES (%s, %s, %s, %s)",
                (soldier_id, rank, unit, False)
            )
            # Store password hash in Redis (not in PostgreSQL for this demo)
            redis_client.set(f'soldier:{soldier_id}:password', password_hash)
        
        conn.commit()
        logger.info(f'Soldier {soldier_id} saved to database')
        return True
    except Exception as e:
        logger.error(f'Error saving soldier to database: {e}')
        if conn:
            conn.rollback()
        return False
    finally:
        if conn:
            db_pool.putconn(conn)

try:
    redis_client = get_redis_connection()
    logger.info('Successfully connected to Redis')
except Exception as e:
    logger.warning(f'Failed to connect to Redis: {e}. Using MockRedis instead.')
    redis_client = MockRedis()

# Initialize PostgreSQL connection pool
try:
    db_pool = get_db_connection_pool()
    logger.info('Successfully connected to PostgreSQL')
except Exception as e:
    logger.warning(f'Failed to connect to PostgreSQL: {e}. Using MockDBConnection instead.')
    db_pool = None

# Training locations
LOCATIONS = {
    'LOCAL': {
        'name': 'Local Training Grounds',
        'description': 'Familiar terrain with established facilities.',
        'benefits': 'Minimal logistics, known environment, close to base support.',
        'image': 'local.svg'
    },
    'MOUNTAIN': {
        'name': 'Mountain Terrain Base',
        'description': 'High-altitude training in challenging conditions.',
        'benefits': 'Altitude conditioning, terrain navigation, cold weather operations.',
        'image': 'mountain.svg'
    },
    'DESERT': {
        'name': 'Desert Combat Center',
        'description': 'Arid environment with extreme temperature variations.',
        'benefits': 'Heat acclimation, long-range operations, minimal cover tactics.',
        'image': 'desert.svg'
    }
}

# Authentication decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'soldier_id' not in session:
            flash('Authentication required', 'danger')
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated_function

# Health check endpoint for Kubernetes
@app.route('/health')
def health():
    status = {
        'status': 'ok',
        'redis_connected': redis_client is not None and redis_client.ping()
    }
    return jsonify(status)

@app.before_request
def handle_bad_session():
    try:
        # Accessing session will raise if the cookie is invalid
        _ = session.items()
    except BadSignature:
        session.clear()
        flash('Session expired or invalid. Please log in again.', 'warning')
        return redirect(url_for('logout'))

@app.route('/')
def index():
    logger.info(f"[INDEX] Session contents: {dict(session)}")
    from datetime import datetime
    now = datetime.utcnow()
    if 'soldier_id' in session:
        return redirect(url_for('vote_form'))
    return render_template('index.html', now=now)

@app.route('/register', methods=['POST'])
def register():
    try:
        # Get form data
        soldier_id = request.form.get('soldier_id', '').strip()
        rank = request.form.get('rank', '').strip()
        unit = request.form.get('unit', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # Validate soldier ID format
        if not soldier_id or not soldier_id.isalnum():
            flash('Invalid Soldier ID format. Use only letters and numbers.', 'danger')
            return redirect(url_for('index'))
        
        # Check if passwords match
        if password != confirm_password:
            flash('Passwords do not match', 'danger')
            return redirect(url_for('index'))
        
        # Check if soldier ID already exists
        if redis_client.exists(f'soldier:{soldier_id}:info'):
            flash('Soldier ID already registered', 'danger')
            return redirect(url_for('index'))
        
        # Validate rank and unit
        if not rank or len(rank) > 10:
            flash('Invalid rank format', 'danger')
            return redirect(url_for('index'))
            
        if not unit or len(unit) > 50:
            flash('Invalid unit format', 'danger')
            return redirect(url_for('index'))
        
        # Hash password
        password_hash = bcrypt_sha256.hash(password)
        
        # Store soldier info in Redis
        soldier_info = {
            'soldier_id': soldier_id,
            'rank': rank,
            'unit': unit
        }
        
        redis_client.set(f'soldier:{soldier_id}:info', json.dumps(soldier_info))
        redis_client.set(f'soldier:{soldier_id}:password', password_hash)
        
        # Persist soldier to PostgreSQL database
        db_success = save_soldier_to_db(soldier_id, rank, unit, password_hash)
        if not db_success:
            logger.warning(f'Failed to save soldier {soldier_id} to PostgreSQL database, but Redis storage succeeded')
        
        logger.info(f'Soldier {soldier_id} registered successfully')
        
        # Automatically log in the user
        session['soldier_id'] = soldier_id
        session['rank'] = rank
        session['unit'] = unit
        
        flash('Registration successful! Welcome to the Military Unit Voting System.', 'success')
        return redirect(url_for('vote_form'))
        
    except Exception as e:
        logger.error(f'Error during registration: {e}')
        flash('System error during registration. Please try again.', 'danger')
        return redirect(url_for('index'))

@app.route('/login', methods=['POST'])
def login():
    try:
        # Get form data
        soldier_id = request.form.get('soldier_id', '').strip()
        password = request.form.get('password', '')
        
        # Validate soldier ID format
        if not soldier_id or not soldier_id.isalnum():
            flash('Invalid Soldier ID format', 'danger')
            return redirect(url_for('index'))
        
        # Get soldier info from Redis
        soldier_info = redis_client.get(f'soldier:{soldier_id}:info')
        
        if not soldier_info:
            flash('Soldier ID not found. Please register first.', 'danger')
            return redirect(url_for('index'))
        
        # Parse soldier data
        soldier_data = json.loads(soldier_info)
        
        # Check if this is legacy data without password (for backward compatibility)
        if 'password_hash' not in soldier_data:
            # Create a password hash for the existing user
            default_password = f"default_{soldier_id}"
            soldier_data['password_hash'] = bcrypt_sha256.hash(default_password)
            redis_client.set(f'soldier:{soldier_id}:info', json.dumps(soldier_data))
            logger.info(f'Added default password for legacy soldier {soldier_id}')
            
            # For testing only - inform about default password
            if password != default_password:
                flash(f'For testing: Use default password: {default_password}', 'warning')
                return redirect(url_for('index'))
        
        # Verify password
        if not bcrypt_sha256.verify(password, soldier_data['password_hash']):
            flash('Invalid password. Please try again.', 'danger')
            return redirect(url_for('index'))
        
        # Store soldier info in session
        session['soldier_id'] = soldier_id
        session['rank'] = soldier_data.get('rank', 'PVT')
        session['unit'] = soldier_data.get('unit', 'Unknown')
        
        # Check if soldier has already voted
        has_voted = redis_client.exists(f'soldier:{soldier_id}:voted')
        if has_voted:
            session['has_voted'] = True
            logger.info(f'Soldier {soldier_id} logged in but has already voted')
            flash('You have already cast your vote. You cannot vote again.', 'warning')
        else:
            session['has_voted'] = False
            logger.info(f'Soldier {soldier_id} logged in successfully')
        
        return redirect(url_for('vote_form'))
        
    except Exception as e:
        logger.error(f'Error during login: {e}')
        flash('System error during authentication. Please try again.', 'danger')
        return redirect(url_for('index'))

@app.route('/vote')
@login_required
def vote_form():
    logger.info(f"[VOTE_FORM] Session contents: {dict(session)}")
    # Always define now at the beginning to ensure it's available in all code paths
    from datetime import datetime
    now = datetime.utcnow()
    
    try:
        # Check if soldier has already voted
        has_voted = redis_client.exists(f'soldier:{session["soldier_id"]}:voted') or session.get('has_voted', False)
        
        if has_voted:
            logger.info(f'Soldier {session["soldier_id"]} attempted to access vote form but has already voted')
            
            # Try to get their previous vote choice if available
            vote_data = redis_client.get(f'soldier:{session["soldier_id"]}:vote')
            location_choice = None
            if vote_data:
                try:
                    vote_info = json.loads(vote_data)
                    location_choice = vote_info.get('location_choice')
                except:
                    pass
            
            # Show read-only view with disabled options
            return render_template('vote.html', 
                            locations=LOCATIONS,
                            soldier_id=session['soldier_id'],
                            rank=session['rank'],
                            unit=session['unit'],
                            now=now,
                            has_voted=True,
                            previous_vote=location_choice)
        
        # Normal voting view for users who haven't voted
        return render_template('vote.html', 
                            locations=LOCATIONS,
                            soldier_id=session['soldier_id'],
                            rank=session['rank'],
                            unit=session['unit'],
                            now=now,
                            has_voted=False)
    except Exception as e:
        logger.error(f'Error in vote form: {e}')
        flash('System error. Please try again later.', 'danger')
        # now is already defined above
        return render_template('index.html', now=now)

@app.route('/submit_vote', methods=['POST'])
@login_required
def submit_vote():
    # Always define now at the beginning to ensure it's available in all code paths
    from datetime import datetime
    now = datetime.utcnow()
    
    try:
        # Double-check if soldier has already voted (prevents race conditions)
        has_voted = redis_client.exists(f'soldier:{session["soldier_id"]}:voted')
        if has_voted:
            logger.warning(f'Duplicate vote attempt by soldier {session["soldier_id"]}')
            flash('You have already voted', 'warning')
            return render_template('confirmation.html', 
                                already_voted=True,
                                soldier_id=session['soldier_id'],
                                rank=session['rank'],
                                unit=session['unit'],
                                now=now)
        
        location_choice = request.form.get('location')
        if not location_choice or location_choice not in LOCATIONS:
            logger.warning(f'Invalid location selection: {location_choice}')
            flash('Invalid location selection', 'danger')
            return redirect(url_for('vote_form'))
        
        # Create vote object
        vote = {
            'vote_id': str(uuid.uuid4()),
            'soldier_id': session['soldier_id'],
            'location_choice': location_choice,
            'timestamp': datetime.utcnow().isoformat(),
            'processed': False,
            'rank': session.get('rank', 'Unknown'),
            'unit': session.get('unit', 'Unknown')
        }
        
        # Use Redis transaction to ensure atomicity
        pipe = redis_client.pipeline()
        
        # Push to Redis queue
        pipe.rpush('votes', json.dumps(vote))
        
        # Mark soldier as voted with timestamp
        pipe.set(f'soldier:{session["soldier_id"]}:voted', datetime.utcnow().isoformat())
        
        # Execute transaction
        pipe.execute()
        
        logger.info(f'Vote submitted successfully by soldier {session["soldier_id"]} for {location_choice}')
        
        # Store vote choice in session for confirmation page
        session['vote_choice'] = location_choice
        
        return redirect(url_for('confirmation'))
    except redis.RedisError as e:
        logger.error(f'Redis error during vote submission: {e}')
        flash('System error processing your vote. Please try again.', 'danger')
        return redirect(url_for('vote_form'))
    except Exception as e:
        logger.error(f'Error during vote submission: {e}')
        flash('System error. Please try again later.', 'danger')
        return redirect(url_for('vote_form'))

@app.route('/confirmation')
@login_required
def confirmation():
    # Always define now at the beginning to ensure it's available in all code paths
    from datetime import datetime
    now = datetime.utcnow()
    
    if 'vote_choice' not in session:
        # Pass now when redirecting to index
        return render_template('index.html', now=now)
    
    location_choice = session['vote_choice']
    location_info = LOCATIONS.get(location_choice, {})
    return render_template('confirmation.html',
                          location=location_info,
                          location_code=location_choice,
                          location_name=location_info.get('name', 'Unknown Location'),
                          soldier_id=session['soldier_id'],
                          rank=session['rank'],
                          unit=session['unit'],
                          now=now)

@app.route('/logout')
def logout():
    soldier_id = session.get('soldier_id')
    session.clear()
    if soldier_id:
        logger.info(f'Soldier {soldier_id} logged out')
    return redirect(url_for('index'))

# Admin endpoint to check voting status (protected by basic auth in a real app)
@app.route('/admin/status')
def admin_status():
    try:
        total_votes = redis_client.llen('votes')
        total_voters = len(redis_client.keys('soldier:*:voted'))
        
        status = {
            'total_votes_queued': total_votes,
            'total_soldiers_voted': total_voters,
            'timestamp': datetime.utcnow().isoformat()
        }
        return jsonify(status)
    except Exception as e:
        logger.error(f'Error in admin status: {e}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=os.environ.get('DEBUG', 'False').lower() == 'true')
