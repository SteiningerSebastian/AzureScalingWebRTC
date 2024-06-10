using ChatFunctionApp;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var creds = await MeteredTURN.CreateNewCredential("global");

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults(b => b.Services
    .AddServerlessHub<ChatHub>())
    .Build();

host.Run();
