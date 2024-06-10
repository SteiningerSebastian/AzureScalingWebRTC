using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.SignalRService;
using Microsoft.Extensions.Logging;
using System.Net.Http.Json;
using static ChatFunctionApp.MeteredTURN;

namespace ChatFunctionApp
{
    [SignalRConnection("AzureSignalRConnectionString")]
    public class ChatHub : ServerlessHub<IChatClient> {
        private const string HubName = nameof(ChatHub);

        private readonly ILogger _logger;
        private readonly IStatisticsRepo _statisticsRepo;
        public ChatHub(IServiceProvider serviceProvider, ILogger<ChatHub> logger) : base(serviceProvider) {
            _logger = logger;
            _statisticsRepo = new StatisticsRepo() ;
        }


        [Function("negotiate")]
        public async Task<HttpResponseData> Negotiate([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req) {
            _logger.LogInformation("C# HTTP trigger function processed a request.");

            var negotiateResponse = await NegotiateAsync(new() { UserId = req.Headers.GetValues("userId").FirstOrDefault() });
            var response = req.CreateResponse();
            response.WriteBytes(negotiateResponse.ToArray());
            return response;
        }

        [Function("broadcast")]
        public async Task Broadcast(
        [SignalRTrigger(HubName, "messages", "broadcast", "message")] SignalRInvocationContext invocationContext, string message) {
            _logger.LogInformation("Broadcasting message.");

            await _statisticsRepo.MessageSent();

            await Clients.All.onMessage(new ChatMessage(invocationContext, message));
            await Clients.All.onStatistics(await _statisticsRepo.GetStatisticsUpdateMessage());
        }

        [Function("aquireturncredential")]
        public async Task AquireTurnCredential(
        [SignalRTrigger(HubName, "messages", "aquireturncredential", "message")] SignalRInvocationContext invocationContext, string region) {
            _logger.LogInformation("Aquireing TURN credentials");
            var creds = await MeteredTURN.CreateNewCredential(region);
            await Clients.Client(invocationContext.ConnectionId).onTURNCredidentials(creds);
        }
    }

    public interface IChatClient {
        Task onMessage(ChatMessage message);
        Task onStatistics(StatisticsUpdateMessage stats);
        Task onTURNCredidentials(IList<TURNCredential> credentials);
    }

    public class ChatMessage {
        public string ConnectionId { get; }
        public string Text { get; }
        public string UserId { get; }

        public ChatMessage(SignalRInvocationContext invocationContext, string message) {
            ConnectionId = invocationContext.ConnectionId;
            Text = message;
            UserId = invocationContext.UserId;
        }
    }
}