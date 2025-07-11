using System.Threading.Tasks;

namespace WorkerService.Services
{
    public interface IRedisService
    {
        Task<string> GetVoteFromQueueAsync();
        Task<long> GetQueueLengthAsync();
        Task<bool> MarkSoldierAsVotedAsync(string soldierId, string timestamp);
    }
}
