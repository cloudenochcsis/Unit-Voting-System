using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using System;
using System.Threading;
using System.Threading.Tasks;
using WorkerService.Services;

namespace WorkerService
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IRedisService _redisService;
        private readonly IVoteProcessor _voteProcessor;
        private readonly int _pollingIntervalMs;

        public Worker(
            ILogger<Worker> logger,
            IRedisService redisService,
            IVoteProcessor voteProcessor,
            IConfiguration configuration)
        {
            _logger = logger;
            _redisService = redisService;
            _voteProcessor = voteProcessor;
            _pollingIntervalMs = configuration.GetValue<int>("PollingIntervalMs", 1000);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Worker service started at: {time}", DateTimeOffset.Now);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Get the next vote from Redis queue
                    var voteJson = await _redisService.GetVoteFromQueueAsync();
                    
                    if (!string.IsNullOrEmpty(voteJson))
                    {
                        _logger.LogInformation("Processing vote: {voteJson}", voteJson);
                        
                        // Process and store the vote
                        await _voteProcessor.ProcessVoteAsync(voteJson);
                    }
                    
                    // Short delay before next poll
                    await Task.Delay(_pollingIntervalMs, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error occurred while processing votes");
                    // Add delay to prevent tight loop in case of persistent errors
                    await Task.Delay(5000, stoppingToken);
                }
            }
            
            _logger.LogInformation("Worker service stopping at: {time}", DateTimeOffset.Now);
        }
    }
}
