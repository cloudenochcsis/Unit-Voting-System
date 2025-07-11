-- Initialize PostgreSQL database for Military Unit Voting System

-- Create tables
CREATE TABLE IF NOT EXISTS voting_sessions (
    session_id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    status VARCHAR(10) NOT NULL CHECK (status IN ('ACTIVE', 'CLOSED', 'PENDING'))
);

CREATE TABLE IF NOT EXISTS soldiers (
    soldier_id VARCHAR(50) PRIMARY KEY,
    rank VARCHAR(10) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    has_voted BOOLEAN DEFAULT FALSE,
    vote_timestamp TIMESTAMP
);

CREATE TABLE IF NOT EXISTS votes (
    vote_id UUID PRIMARY KEY,
    soldier_id VARCHAR(50) NOT NULL REFERENCES soldiers(soldier_id),
    location_choice VARCHAR(20) NOT NULL CHECK (location_choice IN ('LOCAL', 'MOUNTAIN', 'DESERT')),
    timestamp TIMESTAMP NOT NULL,
    processed BOOLEAN DEFAULT FALSE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_votes_soldier_id ON votes(soldier_id);
CREATE INDEX IF NOT EXISTS idx_votes_location_choice ON votes(location_choice);
CREATE INDEX IF NOT EXISTS idx_soldiers_has_voted ON soldiers(has_voted);

-- Insert default voting session
INSERT INTO voting_sessions (session_id, title, description, start_time, end_time, status)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Field Training Exercise Location Selection',
    'Vote for the next month''s training location',
    NOW(),
    NOW() + INTERVAL '7 days',
    'ACTIVE'
)
ON CONFLICT (session_id) DO NOTHING;

-- Insert sample soldiers for testing
INSERT INTO soldiers (soldier_id, rank, unit)
VALUES 
    ('12345', 'SGT', 'Alpha Company'),
    ('23456', 'CPL', 'Bravo Company'),
    ('34567', 'SPC', 'Charlie Company'),
    ('45678', 'PFC', 'Delta Company'),
    ('56789', 'SSG', 'HQ Company')
ON CONFLICT (soldier_id) DO NOTHING;
