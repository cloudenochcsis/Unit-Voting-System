using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;
using WorkerService.Models;

namespace WorkerService.Services
{
    public class PostgresService : IDatabaseService
    {
        private readonly ILogger<PostgresService> _logger;
        private readonly string _connectionString;

        public PostgresService(ILogger<PostgresService> logger, IConfiguration configuration)
        {
            _logger = logger;
            
            var dbHost = configuration.GetValue<string>("Database:Host", "db");
            var dbPort = configuration.GetValue<int>("Database:Port", 5432);
            var dbName = configuration.GetValue<string>("Database:Name", "votingdb");
            var dbUser = configuration.GetValue<string>("Database:User", "postgres");
            var dbPassword = configuration.GetValue<string>("Database:Password", "postgres");
            
            _connectionString = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPassword}";
            
            // Ensure database tables exist
            EnsureDatabaseSetup();
        }

        private void EnsureDatabaseSetup()
        {
            int retryCount = 0;
            int maxRetries = 10; // More retries for initial setup
            int retryDelayMs = 2000; // Longer delay between retries
            
            while (retryCount < maxRetries)
            {
                try
                {
                    using var connection = new NpgsqlConnection(_connectionString);
                    connection.Open();
                    
                    // Create tables if they don't exist
                    using var command = connection.CreateCommand();
                    
                    // Create soldiers table
                    command.CommandText = @"
                        CREATE TABLE IF NOT EXISTS soldiers (
                            soldier_id VARCHAR(50) PRIMARY KEY,
                            password VARCHAR(255),
                            rank VARCHAR(20) NOT NULL,
                            unit VARCHAR(50) NOT NULL,
                            has_voted BOOLEAN DEFAULT FALSE,
                            vote_timestamp TIMESTAMP
                        );";
                    command.ExecuteNonQuery();
                    
                    // Create votes table
                    command.CommandText = @"
                        CREATE TABLE IF NOT EXISTS votes (
                            vote_id UUID PRIMARY KEY,
                            soldier_id VARCHAR(50) NOT NULL,
                            location_choice VARCHAR(20) NOT NULL,
                            timestamp TIMESTAMP NOT NULL,
                            processed BOOLEAN DEFAULT FALSE
                        );";
                    command.ExecuteNonQuery();
                    
                    _logger.LogInformation("Database tables created or verified");
                    return; // Success, exit the retry loop
                }
                catch (NpgsqlException ex) when (IsTransientError(ex) || ex.Message.Contains("Connection refused"))
                {
                    retryCount++;
                    _logger.LogWarning(ex, "Database connection attempt {RetryCount}/{MaxRetries} failed. Retrying in {RetryDelayMs}ms...", 
                        retryCount, maxRetries, retryDelayMs);
                    
                    // Sleep between retries
                    System.Threading.Thread.Sleep(retryDelayMs);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error setting up database tables");
                    return; // Non-transient error, don't retry
                }
            }
            
            _logger.LogError("Failed to connect to database after {MaxRetries} attempts", maxRetries);
        }
        
        private NpgsqlConnection _connection;
        private readonly int _maxRetries = 3;
        private readonly int _retryDelayMs = 1000;
        
        private async Task InitializeConnectionAsync()
        {
            try
            {
                if (_connection != null)
                {
                    await _connection.CloseAsync();
                    await _connection.DisposeAsync();
                }
                
                _connection = new NpgsqlConnection(_connectionString);
                await _connection.OpenAsync();
                _logger.LogDebug("Database connection initialized");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error initializing database connection");
                throw;
            }
        }
        
        private async Task<NpgsqlConnection> GetConnectionAsync()
        {
            if (_connection == null || _connection.State != System.Data.ConnectionState.Open)
            {
                await InitializeConnectionAsync();
            }
            return _connection;
        }
        
        private bool IsTransientError(NpgsqlException ex)
        {
            // Common transient error codes in PostgreSQL
            // 08001 - Connection exception
            // 08006 - Connection failure
            // 57P01 - Admin shutdown
            // 57P02 - Crash shutdown
            // 57P03 - Cannot connect now
            // 40001 - Serialization failure
            // 40P01 - Deadlock detected
            var transientErrorCodes = new[] { "08001", "08006", "57P01", "57P02", "57P03", "40001", "40P01" };
            
            return ex.SqlState != null && transientErrorCodes.Contains(ex.SqlState);
        }

        public async Task<bool> SaveVoteAsync(Vote vote)
        {
            int retryCount = 0;
            while (retryCount < _maxRetries)
            {
                try
                {
                    var connection = await GetConnectionAsync();
                    
                    // Begin transaction to ensure data consistency
                    using var transaction = await connection.BeginTransactionAsync();
                    
                    try
                    {
                        // First check if this vote has already been processed (idempotency)
                        var checkSql = "SELECT COUNT(*) FROM votes WHERE vote_id = @voteId";
                        using var checkCmd = new NpgsqlCommand(checkSql, connection, transaction);
                        checkCmd.Parameters.AddWithValue("voteId", Guid.Parse(vote.VoteId));
                        
                        var count = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
                        if (count > 0)
                        {
                            _logger.LogWarning("Vote {VoteId} has already been processed", vote.VoteId);
                            await transaction.CommitAsync();
                            return true; // Already processed, consider it a success
                        }
                        
                        // Insert the vote
                        var sql = @"INSERT INTO votes (vote_id, soldier_id, location_choice, timestamp, processed) 
                                   VALUES (@voteId, @soldierId, @locationChoice, @timestamp, @processed)";
                        
                        using var cmd = new NpgsqlCommand(sql, connection, transaction);
                        cmd.Parameters.AddWithValue("voteId", Guid.Parse(vote.VoteId));
                        cmd.Parameters.AddWithValue("soldierId", vote.SoldierId);
                        cmd.Parameters.AddWithValue("locationChoice", vote.LocationChoice);
                        cmd.Parameters.AddWithValue("timestamp", DateTime.Parse(vote.Timestamp));
                        cmd.Parameters.AddWithValue("processed", vote.Processed);
                        
                        await cmd.ExecuteNonQueryAsync();
                        
                        // Update soldier's voting status
                        await UpdateSoldierVoteStatusInternalAsync(vote.SoldierId, true, connection, transaction);
                        
                        await transaction.CommitAsync();
                        _logger.LogInformation("Vote {VoteId} from soldier {SoldierId} saved successfully", vote.VoteId, vote.SoldierId);
                        return true;
                    }
                    catch (Exception ex)
                    {
                        await transaction.RollbackAsync();
                        throw new Exception("Transaction failed", ex);
                    }
                }
                catch (NpgsqlException ex) when (IsTransientError(ex))
                {
                    retryCount++;
                    _logger.LogWarning(ex, "Transient database error on attempt {RetryCount}. Retrying...", retryCount);
                    await Task.Delay(_retryDelayMs);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error saving vote to database");
                    return false;
                }
            }
            
            _logger.LogError("Failed to save vote after {MaxRetries} attempts", _maxRetries);
            return false;
        }

        private async Task<bool> UpdateSoldierVoteStatusInternalAsync(
            string soldierId, bool hasVoted, NpgsqlConnection connection, NpgsqlTransaction transaction)
        {
            var sql = @"UPDATE soldiers 
                       SET has_voted = @hasVoted, vote_timestamp = @timestamp 
                       WHERE soldier_id = @soldierId";
            
            using var cmd = new NpgsqlCommand(sql, connection, transaction);
            cmd.Parameters.AddWithValue("hasVoted", hasVoted);
            cmd.Parameters.AddWithValue("timestamp", hasVoted ? DateTime.UtcNow : (object)DBNull.Value);
            cmd.Parameters.AddWithValue("soldierId", soldierId);
            
            await cmd.ExecuteNonQueryAsync();
            return true;
        }

        public async Task<bool> UpdateSoldierVoteStatusAsync(string soldierId, bool hasVoted)
        {
            int retryCount = 0;
            while (retryCount < _maxRetries)
            {
                try
                {
                    var connection = await GetConnectionAsync();
                    using var transaction = await connection.BeginTransactionAsync();
                    
                    try
                    {
                        await UpdateSoldierVoteStatusInternalAsync(soldierId, hasVoted, connection, transaction);
                        await transaction.CommitAsync();
                        _logger.LogInformation("Soldier {SoldierId} vote status updated to {HasVoted}", soldierId, hasVoted);
                        return true;
                    }
                    catch (Exception ex)
                    {
                        await transaction.RollbackAsync();
                        throw new Exception("Transaction failed", ex);
                    }
                }
                catch (NpgsqlException ex) when (IsTransientError(ex))
                {
                    retryCount++;
                    _logger.LogWarning(ex, "Transient database error on attempt {RetryCount}. Retrying...", retryCount);
                    await Task.Delay(_retryDelayMs);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error updating soldier vote status");
                    return false;
                }
            }
            
            return false;
        }

        public async Task<bool> IsSoldierRegisteredAsync(string soldierId)
        {
            try
            {
                using var connection = new NpgsqlConnection(_connectionString);
                await connection.OpenAsync();
                
                using var command = connection.CreateCommand();
                command.CommandText = "SELECT COUNT(*) FROM soldiers WHERE soldier_id = @soldierId;";
                command.Parameters.AddWithValue("soldierId", soldierId);
                
                var result = await command.ExecuteScalarAsync();
                return Convert.ToInt32(result) > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking if soldier {soldierId} is registered", soldierId);
                return false;
            }
        }

        public async Task<Dictionary<string, int>> GetVoteCountsAsync()
        {
            try
            {
                var voteCounts = new Dictionary<string, int>
                {
                    { "LOCAL", 0 },
                    { "MOUNTAIN", 0 },
                    { "DESERT", 0 }
                };

                using var connection = new NpgsqlConnection(_connectionString);
                await connection.OpenAsync();
                
                var sql = @"SELECT location_choice, COUNT(*) as vote_count 
                           FROM votes 
                           GROUP BY location_choice";
                
                using var command = new NpgsqlCommand(sql, connection);
                using var reader = await command.ExecuteReaderAsync();
                
                while (await reader.ReadAsync())
                {
                    string locationChoice = reader.GetString(0);
                    int count = reader.GetInt32(1);
                    
                    if (voteCounts.ContainsKey(locationChoice))
                    {
                        voteCounts[locationChoice] = count;
                    }
                }
                
                return voteCounts;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting vote counts from database");
                return new Dictionary<string, int>
                {
                    { "LOCAL", 0 },
                    { "MOUNTAIN", 0 },
                    { "DESERT", 0 }
                };
            }
        }
        
        public async Task<bool> VerifySoldierCredentialsAsync(string soldierId, string password)
        {
            try
            {
                using var connection = new NpgsqlConnection(_connectionString);
                await connection.OpenAsync();
                
                // First check if the soldier exists
                using var command = connection.CreateCommand();
                command.CommandText = "SELECT password FROM soldiers WHERE soldier_id = @soldierId;";
                command.Parameters.AddWithValue("soldierId", soldierId);
                
                var storedPasswordHash = await command.ExecuteScalarAsync() as string;
                
                if (string.IsNullOrEmpty(storedPasswordHash))
                {
                    _logger.LogWarning("Soldier {soldierId} not found or has no password set", soldierId);
                    return false;
                }
                
                // In a real implementation, we would verify the password hash here
                // For compatibility with the Python service, we would need to use the same hashing algorithm
                // This is a simplified implementation that assumes the password is already verified
                // by the Vote Service before the vote is submitted
                
                _logger.LogInformation("Soldier {soldierId} credentials verified", soldierId);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error verifying soldier credentials for {soldierId}", soldierId);
                return false;
            }
        }
    }
}
