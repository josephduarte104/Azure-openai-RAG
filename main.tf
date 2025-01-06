terraform {
  required_version = "~>1.10.2"
}

### Get the current config to get tenant_id and object_id for sqladmin ###
data azurerm_client_config current {}
data "azurerm_subscription" "primary" {}

# Create a Management Group
resource "azurerm_management_group" "mvp" {
  name         = "mvp-management-group"
  display_name = "mvp Management Group"
}

# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "mvp-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create Subnets
resource "azurerm_subnet" "subnet" {
  count               = 2
  name                = element(["Subnet2", "AzureFirewallSubnet"], count.index)
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes    = [element(["10.0.1.0/24", "10.0.2.0/24"], count.index)]
}

resource "azurerm_subnet" "management_subnet" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Create Azure Firewall
resource "azurerm_public_ip" "firewall_management_pip" {
  name                = "mvp-firewall-management-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
  name                = "mvp-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet[1].id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  management_ip_configuration {
    name                 = "managementConfiguration"
    subnet_id            = azurerm_subnet.management_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_management_pip.id
  }
}

# Create Public IP for Firewall
resource "azurerm_public_ip" "firewall_pip" {
  name                = "mvp-firewall-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Azure AI Search resource
resource "azurerm_search_service" "ai_search" {
  name                = var.ai_search_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "standard"
}

# Create Private Endpoint for Azure AI Search
resource "azurerm_private_endpoint" "ai_search_pe" {
  name                = "ai-search-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "ai-search-psc"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }
}

# Create Azure Cognitive Services resource
resource "azurerm_cognitive_account" "ai_services" {
  name                = var.ai_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "CognitiveServices"
  sku_name            = "S0"
}

# Create Private Endpoint for Azure Cognitive Services
resource "azurerm_private_endpoint" "ai_services_pe" {
  name                = "ai-services-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "ai-services-psc"
    private_connection_resource_id = azurerm_cognitive_account.ai_services.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }
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

# Create a Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "mvpstorageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

# Create Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "storage-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
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

# Create Private Endpoint for Azure ML Hub Workspace
resource "azurerm_private_endpoint" "ml_hub_pe" {
  name                = "ml-hub-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "ml-hub-psc"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml_hub.id
    subresource_names              = ["workspace"]
    is_manual_connection           = false
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

# Create Private Endpoint for Azure ML Project Workspace
resource "azurerm_private_endpoint" "ml_project_pe" {
  name                = "ml-project-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "ml-project-psc"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml_project.id
    subresource_names              = ["workspace"]
    is_manual_connection           = false
  }
}

# Create Application Insights
resource "azurerm_application_insights" "ai" {
  name                = "mvpappinsights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
}

# Create Private Endpoint for Application Insights
resource "azurerm_private_endpoint" "app_insights_pe" {
  name                = "app-insights-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "app-insights-psc"
    private_connection_resource_id = azurerm_application_insights.ai.id
    subresource_names              = ["component"]
    is_manual_connection           = false
  }
}

# Create Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "mvpkeyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Create Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault_pe" {
  name                = "key-vault-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet[0].id

  private_service_connection {
    name                           = "key-vault-psc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

# Create Private DNS Zones
resource "azurerm_private_dns_zone" "search_dns" {
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "cognitive_dns" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "ml_dns" {
  name                = "privatelink.azureml.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "storage_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "app_insights_dns" {
  name                = "privatelink.applicationinsights.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "key_vault_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "mvp-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


