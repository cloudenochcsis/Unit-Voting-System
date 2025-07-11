namespace WorkerService.Services
{
    public interface IVoteProcessor
    {
        Task<bool> ProcessVoteAsync(string voteJson);
    }
}
