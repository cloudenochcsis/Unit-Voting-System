using System.Collections.Generic;
using System.Threading.Tasks;
using WorkerService.Models;

namespace WorkerService.Services
{
    public interface IDatabaseService
    {
        Task<bool> SaveVoteAsync(Vote vote);
        Task<bool> UpdateSoldierVoteStatusAsync(string soldierId, bool hasVoted);
        Task<bool> IsSoldierRegisteredAsync(string soldierId);
        Task<Dictionary<string, int>> GetVoteCountsAsync();
        Task<bool> VerifySoldierCredentialsAsync(string soldierId, string password);
    }
}
