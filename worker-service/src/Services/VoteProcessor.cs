using Microsoft.Extensions.Logging;
using System.Text.Json;
using WorkerService.Models;

namespace WorkerService.Services
{
    public class VoteProcessor : IVoteProcessor
    {
        private readonly ILogger<VoteProcessor> _logger;
        private readonly IDatabaseService _databaseService;

        public VoteProcessor(ILogger<VoteProcessor> logger, IDatabaseService databaseService)
        {
            _logger = logger;
            _databaseService = databaseService;
        }

        public async Task<bool> ProcessVoteAsync(string voteJson)
        {
            try
            {
                // Deserialize the vote JSON
                var vote = JsonSerializer.Deserialize<Vote>(voteJson);
                
                if (vote == null)
                {
                    _logger.LogWarning("Failed to deserialize vote: {voteJson}", voteJson);
                    return false;
                }
                
                // Validate vote data
                if (string.IsNullOrEmpty(vote.VoteId) || 
                    string.IsNullOrEmpty(vote.SoldierId) || 
                    string.IsNullOrEmpty(vote.LocationChoice))
                {
                    _logger.LogWarning("Invalid vote data: {voteJson}", voteJson);
                    return false;
                }
                
                // Validate location choice
                if (!IsValidLocationChoice(vote.LocationChoice))
                {
                    _logger.LogWarning("Invalid location choice: {locationChoice}", vote.LocationChoice);
                    return false;
                }
                
                // Mark vote as processed
                vote.Processed = true;
                
                // Save vote to database
                bool voteStored = await _databaseService.SaveVoteAsync(vote);
                
                if (voteStored)
                {
                    // Update soldier's voting status
                    await _databaseService.UpdateSoldierVoteStatusAsync(vote.SoldierId, true);
                    _logger.LogInformation("Vote {voteId} from soldier {soldierId} processed successfully", 
                        vote.VoteId, vote.SoldierId);
                    return true;
                }
                
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing vote: {voteJson}", voteJson);
                return false;
            }
        }
        
        private bool IsValidLocationChoice(string locationChoice)
        {
            // Valid location choices from requirements
            var validLocations = new[] { "LOCAL", "MOUNTAIN", "DESERT" };
            return validLocations.Contains(locationChoice);
        }
    }
}
