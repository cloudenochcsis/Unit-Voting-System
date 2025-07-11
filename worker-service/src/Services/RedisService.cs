using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using System;
using System.Threading.Tasks;

namespace WorkerService.Services
{
    public class RedisService : IRedisService, IDisposable
    {
        private readonly ILogger<RedisService> _logger;
        private readonly ConnectionMultiplexer _redis;
        private readonly IDatabase _db;
        private readonly string _voteQueue;
        private readonly int _maxRetries;
        private readonly int _retryDelayMs;

        public RedisService(ILogger<RedisService> logger, IConfiguration configuration)
        {
            _logger = logger;
            
            var redisHost = configuration["Redis:Host"] ?? "localhost";
            var redisPort = configuration["Redis:Port"] ?? "6379";
            _voteQueue = configuration["Redis:VoteQueue"] ?? "votes";
            _maxRetries = int.Parse(configuration["Redis:MaxRetries"] ?? "5");
            _retryDelayMs = int.Parse(configuration["Redis:RetryDelayMs"] ?? "1000");
            
            var connectionString = $"{redisHost}:{redisPort}";
            _logger.LogInformation("Connecting to Redis at {ConnectionString}", connectionString);
            
            try
            {
                var options = new ConfigurationOptions
                {
                    EndPoints = { connectionString },
                    ConnectRetry = _maxRetries,
                    ConnectTimeout = 5000,
                    AbortOnConnectFail = false
                };
                
                _redis = ConnectionMultiplexer.Connect(options);
                _db = _redis.GetDatabase();
                
                _logger.LogInformation("Successfully connected to Redis");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Redis");
                throw;
            }
        }

        public async Task<string> GetVoteFromQueueAsync()
        {
            int retryCount = 0;
            while (retryCount < _maxRetries)
            {
                try
                {
                    // LPOP atomically removes and returns the first element of the list
                    var result = await _db.ListLeftPopAsync(_voteQueue);
                    return result.HasValue ? result.ToString() : null;
                }
                catch (Exception ex)
                {
                    retryCount++;
                    _logger.LogError(ex, "Error retrieving vote from Redis queue on attempt {RetryCount}", retryCount);
                    if (retryCount >= _maxRetries) return null;
                    await Task.Delay(_retryDelayMs);
                }
            }
            return null;
        }
        
        public async Task<long> GetQueueLengthAsync()
        {
            try
            {
                return await _db.ListLengthAsync(_voteQueue);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting queue length from Redis");
                return 0;
            }
        }
        
        public async Task<bool> MarkSoldierAsVotedAsync(string soldierId, string timestamp)
        {
            try
            {
                // Store the soldier's vote status in a hash
                var key = "soldier:votes";
                await _db.HashSetAsync(key, soldierId, timestamp);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking soldier {SoldierId} as voted", soldierId);
                return false;
            }
        }
        
        public void Dispose()
        {
            _redis?.Dispose();
        }
    }
}
