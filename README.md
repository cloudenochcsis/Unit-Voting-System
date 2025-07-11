# Military Unit Voting System

A distributed microservice application for military unit voting on training exercise locations. This system demonstrates Docker containerization, Kubernetes orchestration, and modern distributed architecture patterns.

## Project Overview

This application allows soldiers in a military unit to vote on the location for their next field training exercise. The system is built using a microservices architecture with the following components:

1. **Vote Service** (Python/Flask) - Frontend interface for soldiers to register, login, and cast votes
2. **Result Service** (Node.js/Express) - Public results dashboard showing real-time voting statistics
3. **Worker Service** (.NET Core) - Background processing service for vote validation and storage
4. **Redis Service** - Message queue for vote data and temporary storage
5. **Database Service** (PostgreSQL) - Persistent storage for soldiers and processed votes

## Architecture

The application follows a 5-service architecture pattern:

- **Vote Service**: Handles the user interface for soldiers to register, login, and submit their votes. Built with Flask and connects to both Redis (for session management and message queue) and PostgreSQL (for soldier persistence).
- **Result Service**: Provides a fully public real-time dashboard of voting results. Built with Express.js and connects to PostgreSQL. No authentication required.
- **Worker Service**: Processes votes from Redis and stores them in PostgreSQL. Built with .NET Core.
- **Redis**: Acts as a message queue between the Vote Service and Worker Service and provides temporary storage.
- **PostgreSQL**: Stores soldier information and processed votes, providing data for the Result Service.

## Running with Docker Compose

To run the application locally using Docker Compose:

```bash
docker-compose up -d
```

This will start all services and expose the following endpoints:

- Vote Service: http://localhost:5005
- Result Service: http://localhost:5001

### Service Access

- **Vote Service**: Access the voting interface at http://localhost:5005
  - Register with a soldier ID, rank, and unit
  - Login with your soldier ID and password
  - Cast your vote for one of the three training locations

- **Result Service**: View the public results dashboard at http://localhost:5001
  - Real-time vote counts and percentages
  - No authentication required
  - Automatically updates as votes are processed

## Deploying to Kubernetes

The application includes Kubernetes deployment configurations in the `k8s` directory.

1. Apply the namespace first:

```bash
kubectl apply -f k8s/namespace.yaml
```

2. Apply all resources using kustomize:

```bash
kubectl apply -k k8s/
```

3. Access the services:

```bash
kubectl get services -n military-voting
```

## Data Models

### Soldier
- soldier_id (string, unique)
- rank (string)
- unit (string)
- has_voted (boolean)
- vote_timestamp (datetime)

### Vote
- vote_id (uuid)
- soldier_id (string)
- location_choice (enum: LOCAL, MOUNTAIN, DESERT)
- timestamp (datetime)
- processed (boolean)

### Voting Session
- session_id (uuid)
- title (string)
- description (string)
- start_time (datetime)
- end_time (datetime)
- status (enum: ACTIVE, CLOSED, PENDING)

## Recent Updates

### July 2025 Updates

1. **Result Service Improvements**:
   - Made the Result Service fully public with no authentication required
   - Removed login/register functionality from the Result Service
   - Enhanced real-time updates for the dashboard

2. **Vote Service Database Integration**:
   - Added PostgreSQL integration to the Vote Service
   - Implemented proper soldier persistence to the database
   - Fixed foreign key constraint issues in the voting workflow
   - Improved error handling for database operations

3. **System Stability**:
   - Enhanced error handling across all services
   - Improved logging for better debugging
   - Fixed cross-service data consistency issues

## Security Features

- Soldier ID and password-based registration and authentication
- Password hashing for secure storage
- Prevention of duplicate votes through database constraints
- Audit trail for all voting activities with timestamps
- Data persistence across service restarts
- Cross-service data integrity validation

## Development

Each service can be developed independently:

### Vote Service (Python/Flask)
- Located in the `vote-service` directory
- Dependencies: Flask, Redis, PostgreSQL, passlib
- Features: Registration, login, vote submission
- Database: Connects to both Redis and PostgreSQL

```bash
# Build and run the Vote Service individually
docker-compose build vote
docker-compose up -d vote
```

### Result Service (Node.js/Express)
- Located in the `result-service` directory
- Dependencies: Express.js, PostgreSQL, Socket.IO
- Features: Public dashboard, real-time updates
- Database: Connects to PostgreSQL only

```bash
# Build and run the Result Service individually
docker-compose build result
docker-compose up -d result
```

### Worker Service (.NET Core)
- Located in the `worker-service` directory
- Dependencies: .NET Core, StackExchange.Redis, Npgsql
- Features: Vote processing, database persistence
- Database: Connects to both Redis and PostgreSQL

```bash
# Build and run the Worker Service individually
docker-compose build worker
docker-compose up -d worker
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Ensure PostgreSQL is running: `docker-compose ps db`
   - Check connection strings in environment variables

2. **Redis Connection Issues**
   - Ensure Redis is running: `docker-compose ps redis`
   - Verify Redis connection settings

3. **Vote Processing Failures**
   - Check Worker Service logs: `docker-compose logs worker`
   - Verify soldier exists in database before voting

4. **Service Restart**
   - Restart all services: `docker-compose restart`
   - Rebuild a specific service: `docker-compose build <service-name>`

## License

This project is for demonstration purposes only.
