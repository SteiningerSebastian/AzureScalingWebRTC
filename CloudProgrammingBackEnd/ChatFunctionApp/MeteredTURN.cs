using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Json;
using System.Text;
using System.Threading.Tasks;

namespace ChatFunctionApp {
    public static class MeteredTURN {
        public static async Task<IList<TURNCredential>> CreateNewCredential(string? region = "global") {
            var label = Guid.NewGuid().ToString();

            var meteredApp = Environment.GetEnvironmentVariable("metered_app");

            var vaultUri = Environment.GetEnvironmentVariable("KEY_VAULT_URI");
            var client = new SecretClient(new Uri(vaultUri), new DefaultAzureCredential());

            var key = await client.GetSecretAsync("meteredkey");

            //Unfortunately this api feature is not available for the free version
            //of metered TURN. The code below creates temporary credentials.
            //
            //using (HttpClient client = new HttpClient()) {
            //    var resp = await client.PostAsJsonAsync(
            //        $"https://{meteredApp}.metered.live/api/v1/turn/credential?secretKey={key}",
            //        new TRUNCreateCredentialRequest() { expiryInSeconds = 3600, label = label });

            //    resp.EnsureSuccessStatusCode();
            //    var respTurn = await resp.Content.ReadFromJsonAsync<TRUNCreateCredentialResponse>();
            //    if (respTurn is null)
            //        throw new NullReferenceException(nameof(respTurn));

            //    List<TURNCredential>? creds = await client.GetFromJsonAsync<List<TURNCredential>>($"https://{meteredApp}.metered.live/api/v1/turn/credentials?apiKey={respTurn.apiKey}&region={region}");

            //    if (creds is null)
            //        throw new NullReferenceException(nameof(creds));

            //    var liCreds = new List<TURNCredential>() {
            //        new TURNCredential { url = "stun:stun.l.google.com" }
            //    };
            //    liCreds.AddRange(creds);

            //    return liCreds;
            //}

            //Fake it until you makek it!!!
            var liCreds = new List<TURNCredential>() {
                    new TURNCredential { url = "stun:stun.l.google.com" },
                    new TURNCredential { url = "turn:wavenet8.metered.live:80", username="FeatureNotSupportedInTheFreeTier", credential = "Placeholder" },
                    new TURNCredential { url = "turn:wavenet8.metered.live:80?transport=tcp", username="FeatureNotSupportedInTheFreeTier", credential = "Placeholder" },
                    new TURNCredential { url = "turn:wavenet8.metered.live:443", username="FeatureNotSupportedInTheFreeTier", credential = "Placeholder" },
                    new TURNCredential { url = "turn:wavenet8.metered.live:443?transport=tcp", username="FeatureNotSupportedInTheFreeTier", credential = "Placeholder" },
                };
            return liCreds;
        }
    }

    internal record TRUNCreateCredentialResponse {
        public string username { get; set; }
        public string password { get; set; }
        public int expiryInSeconds { get; set; }
        public string label { get; set; }
        public string apiKey { get; set; }
    }

    internal record TRUNCreateCredentialRequest {
        public int expiryInSeconds { get; set; }
        public string label { get; set; }
    }

    public record TURNCredential() {
        required public string url { get; set; }
        public string? username { get; set; }
        public string? credential { get; set; }
    }
}
