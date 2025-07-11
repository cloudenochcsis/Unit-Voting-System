using System.Text.Json.Serialization;

namespace WorkerService.Models
{
    public class Vote
    {
        [JsonPropertyName("vote_id")]
        public string VoteId { get; set; } = string.Empty;
        
        [JsonPropertyName("soldier_id")]
        public string SoldierId { get; set; } = string.Empty;
        
        [JsonPropertyName("location_choice")]
        public string LocationChoice { get; set; } = string.Empty;
        
        [JsonPropertyName("timestamp")]
        public string Timestamp { get; set; } = string.Empty;
        
        [JsonPropertyName("processed")]
        public bool Processed { get; set; }
    }
}
