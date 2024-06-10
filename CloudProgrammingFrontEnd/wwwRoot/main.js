//Inspired by: https://learn.microsoft.com/de-at/azure/azure-signalr/signalr-concept-serverless-development-config

apiBaseUrl = "<>";
let connection = null;
let user = "Anonymous";

//Inspired by: https://github.com/aspnet/AzureSignalR-samples/blob/main/samples/DotnetIsolated-ClassBased/content/index.html
function getConnectionInfo() {
  return axios.post(`${apiBaseUrl}/api/negotiate`, null, {
    headers: {
      "userId": user
    }
  })
    .then(resp => resp.data);
}

function sendMessage() {
  let inpText = document.getElementById("inpText");
  addSentMessage(inpText.value);
  connection.invoke("broadcast", inpText.value)
  inpText.value = ""
}

function updateStats(stats) {
  let spanTodayCount = document.getElementById("todayMessages");
  spanTodayCount.innerText = stats.MessagesToday;

  let spanCount = document.getElementById("sumMessages");
  spanCount.innerText = stats.Messages;
}

function addSentMessage(msg) {
  let chatHistoryDiv = document.getElementById("chatHistory");
  chatHistoryDiv.innerHTML += "<div class=\"sentMsg\">" + msg + "</div>"
}

function addReceivedMessage(msg) {
  let chatHistoryDiv = document.getElementById("chatHistory");
  chatHistoryDiv.innerHTML += "<div class=\"receivedMsg\">" + msg + "</div>"
}

function callOnEnter(self, callback) {
  if (event.keyCode == 13)
    callback();
}

function aquireTurnCredentials() {
  connection.invoke("aquireturncredential", "global");
}

function onTurnCredentials(creds) {
  let turnCredsDiv = document.getElementById("turnCredidentials");
  turnCredsDiv.innerText = JSON.stringify(creds);
}

function login() {
  let inpText = document.getElementById("inpUser");
  user = inpText.value;

  let viewLogin = document.getElementById("login")
  viewLogin.style.display = "none"

  let viewChat = document.getElementById("chat")
  viewChat.style.display = "block"

  //Inspired by: https://github.com/aspnet/AzureSignalR-samples/blob/main/samples/DotnetIsolated-ClassBased/content/index.html
  getConnectionInfo().then(info => {
    const options = {
      accessTokenFactory: () => info.accessToken
    };
    connection = new signalR.HubConnectionBuilder()
      .withUrl(info.url, options)
      .configureLogging(signalR.LogLevel.Information)
      .build();

    connection.on('onMessage', (message) => {
      if (message.ConnectionId != connection.connection.connectionId)
        addReceivedMessage(message.UserId + " says: " + message.Text)
    });

    connection.on('onStatistics', (stats) => {
      updateStats(stats);
    });

    connection.on('onTURNCredidentials', (creds) => {
      onTurnCredentials(creds)
    })

    connection.onclose(() => console.log('disconnected'));
    console.log('connecting...');
    connection.start()
      .then(() => {
        console.log('connected!');
        connection.invoke("broadcast", "Hello there!")
      })
      .catch(console.error);
  }).catch(e => {
    console.error(e);
  });
}