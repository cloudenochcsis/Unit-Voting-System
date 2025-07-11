const express = require('express');
const { Pool } = require('pg');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const moment = require('moment');
const fs = require('fs');
const csv = require('fast-csv');
const session = require('express-session');
require('dotenv').config();

// Enable debug logging in development
const DEBUG = process.env.NODE_ENV !== 'production';

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Set up view engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// No session middleware needed as this is a public service

// Database configuration
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'db',
  database: process.env.DB_NAME || 'votingdb',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
});

// Handle database connection errors
pool.on('error', (err) => {
  console.error('Unexpected database error:', err);
});

// Database helper functions
async function executeQuery(query, params = []) {
  try {
    const result = await pool.query(query, params);
    return { success: true, data: result.rows };
  } catch (err) {
    console.error('Database query error:', err);
    return { success: false, error: err.message };
  }
}

// Location options (same as in Vote Service)
const LOCATIONS = {
  'LOCAL': 'Local Training Grounds',
  'MOUNTAIN': 'Mountain Terrain Base',
  'DESERT': 'Desert Combat Center'
};

// No authentication middleware needed as this is a public service
function publicAccess(req, res, next) {
  // All routes are publicly accessible
  return next();
}

// No authentication routes needed as this is a public service

// Public dashboard route - no authentication required
app.get('/', async (req, res) => {
  try {
    // Get active voting session
    const sessionResult = await pool.query(
      'SELECT * FROM voting_sessions WHERE status = $1 ORDER BY start_time DESC LIMIT 1',
      ['ACTIVE']
    );
    
    const activeSession = sessionResult.rows[0] || {
      title: 'Field Training Exercise Location Selection',
      description: 'Vote for the next month\'s training location',
      status: 'ACTIVE'
    };
    
    res.render('dashboard', { 
      session: activeSession,
      locations: LOCATIONS,
      moment: moment,
      // No authentication needed, all users are anonymous
      soldier_id: null,
      rank: null,
      unit: null,
      isAuthenticated: false
    });
  } catch (err) {
    console.error('Error fetching dashboard data:', err);
    res.status(500).render('error', { 
      message: 'Error loading dashboard',
      error: process.env.NODE_ENV === 'development' ? err : {}
    });
  }
});

// Admin route for session management - now public since no authentication is needed
app.get('/admin', publicAccess, async (req, res) => {
  try {
    // Get all voting sessions
    const sessionsResult = await pool.query(
      'SELECT * FROM voting_sessions ORDER BY start_time DESC'
    );
    
    res.render('admin', { 
      sessions: sessionsResult.rows,
      moment: moment
    });
  } catch (err) {
    console.error('Error fetching admin data:', err);
    res.status(500).render('error', { 
      message: 'Error loading admin panel',
      error: process.env.NODE_ENV === 'development' ? err : {}
    });
  }
});

// API endpoint to get current vote counts
app.get('/api/results', async (req, res) => {
  try {
    const results = await getFormattedResults();
    
    if (!results.success) {
      throw new Error(results.error);
    }
    
    res.json(results.data);
  } catch (err) {
    console.error('Error fetching results:', err);
    res.status(500).json({ error: 'Error fetching results' });
  }
});

// API endpoint for detailed vote statistics
app.get('/api/stats', async (req, res) => {
  try {
    // Get vote counts by location
    const votesQuery = await executeQuery(`
      SELECT location_choice, COUNT(*) as count 
      FROM votes 
      WHERE processed = true 
      GROUP BY location_choice
    `);
    
    if (!votesQuery.success) {
      throw new Error(votesQuery.error);
    }
    
    // Get vote counts by unit
    const unitQuery = await executeQuery(`
      SELECT s.unit, COUNT(*) as count 
      FROM votes v
      JOIN soldiers s ON v.soldier_id = s.soldier_id
      WHERE v.processed = true 
      GROUP BY s.unit
      ORDER BY count DESC
    `);
    
    if (!unitQuery.success) {
      throw new Error(unitQuery.error);
    }
    
    // Get vote counts by rank
    const rankQuery = await executeQuery(`
      SELECT s.rank, COUNT(*) as count 
      FROM votes v
      JOIN soldiers s ON v.soldier_id = s.soldier_id
      WHERE v.processed = true 
      GROUP BY s.rank
      ORDER BY count DESC
    `);
    
    if (!rankQuery.success) {
      throw new Error(rankQuery.error);
    }
    
    // Get hourly vote distribution
    const hourlyQuery = await executeQuery(`
      SELECT 
        EXTRACT(HOUR FROM timestamp) as hour,
        COUNT(*) as count
      FROM votes
      WHERE processed = true
      GROUP BY hour
      ORDER BY hour
    `);
    
    if (!hourlyQuery.success) {
      throw new Error(hourlyQuery.error);
    }
    
    // Get voting session info
    const sessionQuery = await executeQuery(
      'SELECT * FROM voting_sessions WHERE status = $1 ORDER BY start_time DESC LIMIT 1',
      ['ACTIVE']
    );
    
    if (!sessionQuery.success) {
      throw new Error(sessionQuery.error);
    }
    
    const stats = {
      byLocation: votesQuery.data,
      byUnit: unitQuery.data,
      byRank: rankQuery.data,
      hourlyDistribution: hourlyQuery.data,
      session: sessionQuery.data[0] || {
        title: 'Field Training Exercise Location Selection',
        description: 'Vote for the next month\'s training location',
        status: 'ACTIVE'
      }
    };
    
    res.json(stats);
  } catch (err) {
    console.error('Error fetching statistics:', err);
    res.status(500).json({ error: 'Error fetching statistics' });
  }
});

// Export results as CSV
app.get('/api/export', async (req, res) => {
  try {
    const format = req.query.format || 'csv';
    const type = req.query.type || 'detailed';
    
    // Query for detailed vote data (anonymized)
    const votesQuery = await executeQuery(`
      SELECT 
        v.vote_id,
        v.location_choice,
        v.timestamp,
        s.rank,
        s.unit
      FROM votes v
      JOIN soldiers s ON v.soldier_id = s.soldier_id
      WHERE v.processed = true
      ORDER BY v.timestamp
    `);
    
    if (!votesQuery.success) {
      throw new Error(votesQuery.error);
    }
    
    if (format === 'json') {
      // Return JSON format
      return res.json({
        exportDate: new Date().toISOString(),
        votes: votesQuery.data,
        totalVotes: votesQuery.data.length
      });
    } else {
      // CSV format
      const csvStream = csv.format({ headers: true });
      const filename = `voting-results-${new Date().toISOString().split('T')[0]}.csv`;
      
      // Set headers for file download
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename=${filename}`);
      
      // Pipe the CSV data to the response
      csvStream.pipe(res);
      
      // Add rows based on export type
      if (type === 'summary') {
        // Get summary data
        const summaryQuery = await executeQuery(`
          SELECT location_choice, COUNT(*) as count
          FROM votes
          WHERE processed = true
          GROUP BY location_choice
        `);
        
        if (!summaryQuery.success) {
          throw new Error(summaryQuery.error);
        }
        
        // Write summary data
        summaryQuery.data.forEach(row => {
          csvStream.write({
            'Location': row.location_choice,
            'Location Name': LOCATIONS[row.location_choice] || row.location_choice,
            'Vote Count': row.count
          });
        });
      } else {
        // Write detailed data
        votesQuery.data.forEach(row => {
          csvStream.write({
            'Vote ID': row.vote_id,
            'Location': row.location_choice,
            'Location Name': LOCATIONS[row.location_choice] || row.location_choice,
            'Timestamp': row.timestamp,
            'Rank': row.rank,
            'Unit': row.unit
          });
        });
      }
      
      // End the CSV stream
      csvStream.end();
    }
  } catch (err) {
    console.error('Error exporting results:', err);
    res.status(500).send('Error exporting results');
  }
});

// Export results as PDF report
app.get('/api/report', async (req, res) => {
  try {
    // Get formatted results
    const results = await getFormattedResults();
    
    if (!results.success) {
      throw new Error(results.error);
    }
    
    // Get session info
    const sessionQuery = await executeQuery(
      'SELECT * FROM voting_sessions WHERE status = $1 ORDER BY start_time DESC LIMIT 1',
      ['ACTIVE']
    );
    
    if (!sessionQuery.success) {
      throw new Error(sessionQuery.error);
    }
    
    // Format report data
    const reportData = {
      title: 'Military Unit Voting Results',
      session: sessionQuery.data[0] || {
        title: 'Field Training Exercise Location Selection',
        description: 'Vote for the next month\'s training location',
        status: 'ACTIVE'
      },
      results: results.data,
      generatedAt: new Date().toISOString(),
      exportType: 'Official Report'
    };
    
    res.json(reportData);
  } catch (err) {
    console.error('Error generating report:', err);
    res.status(500).json({ error: 'Error generating report' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Socket.io for real-time updates
io.on('connection', (socket) => {
  console.log('Client connected');
  
  // Send initial results on connection
  sendVoteUpdate(socket);
  
  // Set up interval to check for updates
  const intervalId = setInterval(() => {
    sendVoteUpdate(socket);
  }, 3000);
  
  socket.on('disconnect', () => {
    clearInterval(intervalId);
    console.log('Client disconnected');
  });
});

// Helper function to get formatted vote results
async function getFormattedResults() {
  try {
    // Get vote counts by location
    const votesQuery = await executeQuery(`
      SELECT location_choice, COUNT(*) as count 
      FROM votes 
      WHERE processed = true 
      GROUP BY location_choice
    `);
    
    if (!votesQuery.success) {
      return { success: false, error: votesQuery.error };
    }
    
    // Get total soldier count
    const soldiersQuery = await executeQuery('SELECT COUNT(*) as total FROM soldiers');
    
    if (!soldiersQuery.success) {
      return { success: false, error: soldiersQuery.error };
    }
    
    // Get soldiers who have voted
    const votedQuery = await executeQuery('SELECT COUNT(*) as voted FROM soldiers WHERE has_voted = true');
    
    if (!votedQuery.success) {
      return { success: false, error: votedQuery.error };
    }
    
    // Format results
    const results = {
      locations: {},
      totalVotes: 0,
      totalSoldiers: parseInt(soldiersQuery.data[0]?.total || 0),
      soldierVoted: parseInt(votedQuery.data[0]?.voted || 0),
      participationRate: 0,
      lastUpdated: new Date().toISOString()
    };
    
    // Initialize with zero counts for all locations
    Object.keys(LOCATIONS).forEach(loc => {
      results.locations[loc] = {
        name: LOCATIONS[loc],
        count: 0,
        percentage: 0
      };
    });
    
    // Fill in actual vote counts
    votesQuery.data.forEach(row => {
      if (results.locations[row.location_choice]) {
        results.locations[row.location_choice].count = parseInt(row.count);
        results.totalVotes += parseInt(row.count);
      }
    });
    
    // Calculate percentages
    if (results.totalVotes > 0) {
      Object.keys(results.locations).forEach(loc => {
        results.locations[loc].percentage = 
          Math.round((results.locations[loc].count / results.totalVotes) * 100);
      });
    }
    
    // Calculate participation rate
    if (results.totalSoldiers > 0) {
      results.participationRate = 
        Math.round((results.soldierVoted / results.totalSoldiers) * 100);
    }
    
    return { success: true, data: results };
  } catch (err) {
    console.error('Error formatting results:', err);
    return { success: false, error: err.message };
  }
}

// Function to send vote updates to connected clients
async function sendVoteUpdate(socket) {
  try {
    const results = await getFormattedResults();
    
    if (results.success) {
      // Emit to client(s)
      socket.emit('vote-update', results.data);
      
      if (DEBUG) {
        console.log(`Sent vote update to client. Total votes: ${results.data.totalVotes}`);
      }
    } else {
      console.error('Error getting formatted results for socket update:', results.error);
    }
  } catch (err) {
    console.error('Error sending vote update:', err);
  }
}

// Start server
const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`Result service running on port ${PORT}`);
});
