# From Gemini (2024, https://gemini.google.com/), created based on the text below the rhyme.
# ------------------------------------------------------------------------
# A script awaits your call, a loyal friend and guide,
# To build your infrastructure, with secrets it confides.
# But first, a key it needs, a passport to the land,
# The metered_key, so potent, held close within your hand.

# With steady hand you type, a magic whispered phrase,
# -var "metered_key=<your_api_key>" it displays.
# This grants the script its power, the secrets to unfold,
# Your first deployment beckons, a story yet untold.

# But journeys have their twists, and updates come to play,
# The metered_key's not always, the best and safest way.
# A vault awaits, a haven, with Azure's watchful eye,
# The Azure Key Vault, a fortress standing high.

# Within its walls, a treasure, the metered key shall dwell,
# No longer in plain sight, a story it can tell.
# The vault's ID, a beacon, a guiding star so bright,
# Leads the script to find the key, and bathe your code in light.

# So for your next deployment, a different path you'll tread,
# With terraform plan you start, a powerful command spread.
# -var "azure_key_vault_id=<your_key_vault_id>" you say,
# The script retrieves the key, in a more secure display.

# No longer burdened by secrets, your code is free to roam,
# With security its armor, a safe and happy home.
# So let your infrastructure flourish, with power and with grace,
# The script, your loyal partner, a smile upon its face.
# ------------------------------------------------------------------------

# If you run this script for the first time, run it with -var "metered_key=<api-key>" to specify the metered api key.
# If you try to update an existing deployment, you have the option to set "azure_key_vault_id" instead.
# The script will get the metered key from the vault and us it instead of the optional metered_key.
# You can use this command after the first deployment: terraform plan -var "azure_key_vault_id=<azure_key_vault_id>"
# The key_vault_id can be found in the properties tab of the key vault, it is called the Resource ID.

# The IP Address that should be granted access to the sql server.
variable "azure_key_vault_id" {
  description = "The id of the keyvault containing the keys."
  type        = string
  default     = ""
}

data "azurerm_key_vault_secret" "metered_key" {
  name         = "meteredkey"
  key_vault_id = var.azure_key_vault_id
  count        = var.azure_key_vault_id == "" ? 0 : 1
}

variable "metered_key" {
  type      = string
  default   = ""
  sensitive = true
}

# The public Ip is needed to configure the firewall to allow connections to the database from the team.
variable "public_ip_address_of_it_team" {
  type    = string
  default = "" #This can be changed if the ip changes, assuming a static ip, so default.
}

# A suffix is used to identify versions, etc. It is added to every resources name.
variable "suffix" {
  type        = string
  description = "A suffix should be unique amd is applyed to all resources to avoid conflicts with previous ressources not correctly destroyed."
  default     = "v1"
}

# The name of the resource group, the suffix is NOT applied to this value.
variable "resourcegroup" {
  type        = string
  description = "A unique name for the ressource group to deploy the infrastrucutre."
  default     = "MyWebRTCDeployment"
}

# The name of the app in metered, to connect to the api.
variable "metered_app" {
  type        = string
  sensitive   = true
  description = "The appname to use to connect with the metered api."
  default     = "wavenet8"
}

# The skus used to define the services.
variable "sku_key_vault" {
  type        = string
  description = "The service Tier for the key vault (development: \"standard\", production: \"standard\")"
  default     = "standard"
}

variable "sku_signalR" {
  type        = string
  description = "The service Tier for the signalR Service (development: \"Free_F1\", production: \"Premium_P2\")"
  default     = "Free_F1"
}

variable "sku_database" {
  type        = string
  description = "The service Tier for the database (development: \"Basic\", production: \"Premium\")"
  default     = "Basic"
}

variable "sku_service_plan" {
  type        = string
  description = "The service Tier for the service plan associated with the function App (development: \"Y1\",\"Y1\" )"
  default     = "Y1"
}

data "azurerm_client_config" "current" {}

data "azuread_user" "current_user" {
  object_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "main_resource_group" {
  location = "westeurope"
  name     = var.resourcegroup
}

resource "azurerm_key_vault" "main_key_vault" {
  enable_rbac_authorization       = true
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  location                        = "westeurope"
  name                            = format("mydeploymentkv%s", var.suffix)
  resource_group_name             = azurerm_resource_group.main_resource_group.name
  sku_name                        = var.sku_key_vault
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled        = false
}

# Define a new groups and add a new members.
resource "azuread_group" "dbadmin_group" {
  display_name     = "DBAdmin"
  security_enabled = true
}

resource "azuread_group_member" "dbadmin_group_member_current" {
  group_object_id  = azuread_group.dbadmin_group.object_id
  member_object_id = data.azurerm_client_config.current.object_id
}

# Group for pipelines
resource "azuread_group" "pipelines_group" {
  display_name     = "AzurePipelinePrincipals"
  security_enabled = true
}

# Make the pipelines group a member of dbadmin.
resource "azuread_group_member" "dbadmin_group_member_pipelines_group" {
  group_object_id  = azuread_group.dbadmin_group.object_id
  member_object_id = azuread_group.pipelines_group.object_id
}

# This is necessary to add the service principal (App Registration) for the build pipeline.
resource "azurerm_role_assignment" "key_vault_admin_role_assignment_current" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.main_key_vault.id
  depends_on = [
    azurerm_key_vault.main_key_vault,
  ]
}
resource "azurerm_role_assignment" "key_vault_secrets_user_role_assignment_main_signalr_service" {
  principal_id         = azurerm_signalr_service.main_signalr_service.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.main_key_vault.id
  depends_on = [
    azurerm_key_vault.main_key_vault,
  ]
}
resource "azurerm_role_assignment" "key_vault_secrets_user_role_assignment_chat_function_app" {
  principal_id         = azurerm_windows_function_app.main_windows_function_app.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.main_key_vault.id
  depends_on = [
    azurerm_key_vault.main_key_vault,
  ]
}
resource "azurerm_role_assignment" "key_vault_secrets_officer_role_assignment_chat_function_app" {
  principal_id         = azurerm_windows_function_app.main_windows_function_app.identity[0].principal_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.main_key_vault.id
  depends_on = [
    azurerm_key_vault.main_key_vault,
  ]
}

# The pipeline must be able to deploy the Functions app. 
resource "azurerm_role_assignment" "contributor_role_assignment_chat_function_app" {
  principal_id         = azuread_group.pipelines_group.object_id
  role_definition_name = "Contributor"
  scope                = azurerm_windows_function_app.main_windows_function_app.id
  depends_on = [
    azurerm_windows_function_app.main_windows_function_app,
  ]
}

# The assignment of the Directory Readers role is necessary for creating the db user in the pipelines.
resource "azuread_directory_role" "directory_readers_azuread_directory_role" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "mssql_server_directory_role_assignment_directory_readers" {
  role_id             = azuread_directory_role.directory_readers_azuread_directory_role.template_id
  principal_object_id = azurerm_mssql_server.main_mssql_server.identity[0].principal_id
}

#The secrets needed, stored securely in a vault.
resource "azurerm_key_vault_secret" "azure_web_jobs_storage_key_vault_secret" {
  key_vault_id = azurerm_key_vault.main_key_vault.id
  name         = "AzureWebJobsStorage"
  value        = format("DefaultEndpointsProtocol=https;AccountName=%s;AccountKey=%s;EndpointSuffix=core.windows.net", azurerm_storage_account.main_storage_account.name, azurerm_storage_account.main_storage_account.primary_access_key)
  depends_on = [
    azurerm_key_vault.main_key_vault,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}
resource "azurerm_key_vault_secret" "application_insights_key_vault_secret" {
  key_vault_id = azurerm_key_vault.main_key_vault.id
  name         = "applicationinsightsconnectionstring"
  value        = azurerm_application_insights.main_application_insights.connection_string
  depends_on = [
    azurerm_key_vault.main_key_vault,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}
resource "azurerm_key_vault_secret" "metered_key_key_vault_secret" {
  key_vault_id = azurerm_key_vault.main_key_vault.id
  name         = "meteredkey"
  value        = var.metered_key == "" ? (var.azure_key_vault_id == "" ? "" : data.azurerm_key_vault_secret.metered_key[0].value) : var.metered_key
  depends_on = [
    azurerm_key_vault.main_key_vault,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}
resource "azurerm_key_vault_secret" "signalr_key_vault_secret" {
  key_vault_id = azurerm_key_vault.main_key_vault.id
  name         = "signalRConnectionString"
  value        = azurerm_signalr_service.main_signalr_service.primary_connection_string
  depends_on = [
    azurerm_key_vault.main_key_vault,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}
resource "azurerm_key_vault_secret" "content_file_key_vault_secret" {
  key_vault_id = azurerm_key_vault.main_key_vault.id
  name         = "contentazurefileconnectionstring"
  value        = format("DefaultEndpointsProtocol=https;AccountName=%s;AccountKey=%s;EndpointSuffix=core.windows.net", azurerm_storage_account.main_storage_account.name, azurerm_storage_account.main_storage_account.primary_access_key)
  depends_on = [
    azurerm_key_vault.main_key_vault,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}

#The signalR service to which the clients connect after negotiating with the functionsApp.
resource "azurerm_signalr_service" "main_signalr_service" {
  location            = "westeurope"
  name                = format("mydeploymentSigR%s", var.suffix)
  resource_group_name = azurerm_resource_group.main_resource_group.name
  service_mode        = "Serverless"
  identity {
    type = "SystemAssigned"
  }
  sku {
    capacity = 1
    name     = var.sku_signalR
  }
  upstream_endpoint {
    category_pattern = ["*"]
    event_pattern    = ["*"]
    hub_pattern      = ["*"]
    url_template     = format("https://%s/runtime/webhooks/signalr?code={@Microsoft.KeyVault(SecretUri=%ssecrets/host--systemKey--signalr-095extension/)}", azurerm_windows_function_app.main_windows_function_app.default_hostname, azurerm_key_vault.main_key_vault.vault_uri)
  }
  timeouts {
    create = "45m"
    update = "30m"
    delete = "45m"
  }
}

#The sql server hosting the databse.
resource "azurerm_mssql_server" "main_mssql_server" {
  location            = "westeurope"
  name                = format("mydeploymentmssql%s", var.suffix)
  resource_group_name = azurerm_resource_group.main_resource_group.name
  version             = "12.0"
  # Set the DBAdmin group as Administrator of the db
  azuread_administrator {
    login_username              = azuread_group.dbadmin_group.display_name #data.azuread_user.current_user.user_principal_name
    object_id                   = azuread_group.dbadmin_group.object_id    #data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
  identity {
    type = "SystemAssigned"
  }
  timeouts {
    create = "60m"
    update = "45m"
    delete = "60m"
  }
}

#The database sotring all the statistics.
resource "azurerm_mssql_database" "main_mssql_database" {
  name                 = format("mydeploymentDB%s", var.suffix)
  server_id            = azurerm_mssql_server.main_mssql_server.id
  storage_account_type = "Local"
  sku_name             = var.sku_database
  depends_on = [
    azurerm_mssql_server.main_mssql_server,
  ]
}

#Firewall rules to allow azure servers to access the DB-Server and the local IT-Team.
resource "azurerm_mssql_firewall_rule" "azure_services_mssql_firewall_rule" {
  end_ip_address   = "0.0.0.0"
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.main_mssql_server.id
  start_ip_address = "0.0.0.0"
  depends_on = [
    azurerm_mssql_server.main_mssql_server,
  ]
}
resource "azurerm_mssql_firewall_rule" "public_ip_mssql_firewall_rule" {
  end_ip_address   = var.public_ip_address_of_it_team
  name             = "ClientIPAddress"
  server_id        = azurerm_mssql_server.main_mssql_server.id
  start_ip_address = var.public_ip_address_of_it_team
  depends_on = [
    azurerm_mssql_server.main_mssql_server,
  ]
}

resource "azurerm_role_assignment" "sql_server_contributor_role_assignment" {
  principal_id         = azurerm_windows_function_app.main_windows_function_app.identity[0].principal_id
  role_definition_name = "SQL Server Contributor"
  scope                = azurerm_mssql_server.main_mssql_server.id
  depends_on = [
    azurerm_mssql_server.main_mssql_server,
  ]
}

#The sotrage account necessary for the FunctionsApp, created while creating the FunctionsApp.
resource "azurerm_storage_account" "main_storage_account" {
  account_kind                     = "Storage"
  account_replication_type         = "LRS"
  account_tier                     = "Standard"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  default_to_oauth_authentication  = true
  location                         = "westeurope"
  min_tls_version                  = "TLS1_0"
  name                             = format("mydeploymentsta%s", var.suffix)
  resource_group_name              = azurerm_resource_group.main_resource_group.name
  tags = {

  }
}
resource "azurerm_storage_container" "webjobs_storage_container" {
  name                 = "azure-webjobs-hosts"
  storage_account_name = azurerm_storage_account.main_storage_account.name
}
resource "azurerm_storage_container" "webjobs_secrets_storage_container" {
  name                 = "azure-webjobs-secrets"
  storage_account_name = azurerm_storage_account.main_storage_account.name
}
resource "azurerm_storage_share" "chat_function_store_storage_share" {
  name                 = format("mystore%s", var.suffix)
  quota                = 5120
  storage_account_name = azurerm_storage_account.main_storage_account.name
}

#Service plan for the Functions app.
resource "azurerm_service_plan" "main_service_plan" {
  location            = "westeurope"
  name                = "WestEuropePlan"
  os_type             = "Windows"
  resource_group_name = azurerm_resource_group.main_resource_group.name
  sku_name            = var.sku_service_plan
}

#The static side, default configuration.
resource "azurerm_static_site" "main_static_site" {
  location            = "westeurope"
  name                = format("mydeploymentStSite%s", var.suffix)
  resource_group_name = azurerm_resource_group.main_resource_group.name
}

#The needed workspace
resource "azurerm_log_analytics_workspace" "main_log_analytics_workspace" {
  name                = format("mydeploymentlog%s", var.suffix)
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.main_resource_group.name
}

#The application insights for the functions app.
resource "azurerm_application_insights" "main_application_insights" {
  application_type    = "web"
  location            = "westeurope"
  name                = format("mydeploymentins%s", var.suffix)
  resource_group_name = azurerm_resource_group.main_resource_group.name
  sampling_percentage = 0
  workspace_id        = azurerm_log_analytics_workspace.main_log_analytics_workspace.id
}

#The functions app hosting the functions, connnected with SignalR.
resource "azurerm_windows_function_app" "main_windows_function_app" {
  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING  = format("@Microsoft.KeyVault(SecretUri=%ssecrets/applicationinsightsconnectionstring/)", azurerm_key_vault.main_key_vault.vault_uri)
    ASPNETCORE_HOSTINGSTARTUPASSEMBLIES    = "Microsoft.Azure.SignalR"
    AzureSignalRConnectionString           = format("@Microsoft.KeyVault(SecretUri=%ssecrets/signalRConnectionString/)", azurerm_key_vault.main_key_vault.vault_uri)
    Azure__SignalR__StickyServerMode       = "Required"
    KEY_VAULT_URI                          = azurerm_key_vault.main_key_vault.vault_uri
    WEBSITE_RUN_FROM_PACKAGE               = "1"
    WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED = "1"
    metered_app                            = var.metered_app
    sqldb_connection                       = format("Server=tcp:%s,1433;Initial Catalog=%s;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=\"Active Directory Default\";", azurerm_mssql_server.main_mssql_server.fully_qualified_domain_name, azurerm_mssql_database.main_mssql_database.name)
    AzureWebJobsStorage                    = format("@Microsoft.KeyVault(SecretUri=%ssecrets/AzureWebJobsStorage/)", azurerm_key_vault.main_key_vault.vault_uri)
    FUNCTIONS_EXTENSION_VERSION            = "~4"
    FUNCTIONS_WORKER_RUNTIME               = "dotnet-isolated"
    WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED = "1"
    WEBSITE_RUN_FROM_PACKAGE               = "1"
    WEBSITE_CONTENTSHARE                   = azurerm_storage_share.chat_function_store_storage_share.name

    #Inspired by: https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#azurewebjobssecretstoragetype
    AzureWebJobsSecretStorageType        = "keyvault"
    AzureWebJobsSecretStorageKeyVaultUri = azurerm_key_vault.main_key_vault.vault_uri
  }
  builtin_logging_enabled    = false
  client_certificate_mode    = "Required"
  location                   = "westeurope"
  name                       = format("mydeploymentfuncApp%s", var.suffix)
  resource_group_name        = azurerm_resource_group.main_resource_group.name
  service_plan_id            = azurerm_service_plan.main_service_plan.id
  storage_account_access_key = azurerm_storage_account.main_storage_account.primary_access_key
  storage_account_name       = azurerm_storage_account.main_storage_account.name
  tags = {
  }
  identity {
    type = "SystemAssigned"
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.main_application_insights.connection_string
    ftps_state                             = "FtpsOnly"
    http2_enabled                          = true
    use_32_bit_worker                      = false
    websockets_enabled                     = true
    application_stack {
      #Use the v7.0 (.Net 7.0) until v8.0 is fully supported in pipelines, etc.
      dotnet_version              = "v7.0"
      use_dotnet_isolated_runtime = true
    }
    cors {
      allowed_origins     = [format("https://%s", azurerm_static_site.main_static_site.default_host_name)]
      support_credentials = true
    }
  }
  sticky_settings {
    app_setting_names = ["AzureSignalRConnectionString", "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES", "Azure__SignalR__StickyServerMode"]
  }
  depends_on = [
    azurerm_service_plan.main_service_plan,
    azurerm_role_assignment.key_vault_admin_role_assignment_current
  ]
}
