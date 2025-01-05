terraform {
  required_version = "~>1.10.2"
}

### Get the current config to get tenant_id and object_id for sqladmin ###
data azurerm_client_config current {}
data "azurerm_subscription" "primary" {}

# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# Create Azure AI Search resource
resource "azurerm_search_service" "ai_search" {
  name                = var.ai_search_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "free"
}

# Create Azure Cognitive Services resource
resource "azurerm_cognitive_account" "ai_services" {
  name                = var.ai_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "CognitiveServices"
  sku_name            = "S0"
}

# Create GPT-4o deployment
resource "azurerm_cognitive_deployment" "gpt4o_deployment" {
  name                = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.ai_services.id
  model {
    name    = "gpt-4o"
    version = "2024-05-13"
    format  = "OpenAI"
  }
  sku {
    name     = "GlobalStandard"
    capacity = 150
  }
}


# Create an Azure ML Hub Workspace
resource "azurerm_machine_learning_workspace" "ml_hub" {
  name                = var.hub_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  kind                = "Default"
  storage_account_id  = azurerm_storage_account.sa.id
  application_insights_id = azurerm_application_insights.ai.id
  key_vault_id        = azurerm_key_vault.kv.id

  identity {
    type = "SystemAssigned"
  }
}

# Create an Azure ML Project Workspace
resource "azurerm_machine_learning_workspace" "ml_project" {
  name                = var.project_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "Default"
  key_vault_id        = azurerm_key_vault.kv.id
  storage_account_id  = azurerm_storage_account.sa.id
  application_insights_id = azurerm_application_insights.ai.id

  identity {
    type = "SystemAssigned"
  }
}

# Create a Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "examplestorageacc"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create Application Insights
resource "azurerm_application_insights" "ai" {
  name                = "exampleappinsights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
}

# Create Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "examplekeyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}



