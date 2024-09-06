terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  # Configuration options
}

data "azurerm_client_config" "current" {}


resource "azurerm_resource_group" "RG-ResumeAPI" {
  name     = "resume-api"
  location = "East US"
}

resource "azurerm_key_vault" "Key-Vault" {
  name                        = "api55237"
  location                    = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name         = azurerm_resource_group.RG-ResumeAPI.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id


    secret_permissions = ["Get", "List"]
  }
}

data "azurerm_key_vault_secret" "SA-ResumeAPI-AK" {
  name         = "SA-ResumeAPI-AK"
  key_vault_id = data.azurerm_key_vault.Key-Vault.id
}

output "secret_value" {
  value     = data.azurerm_key_vault_secret.example.value
  sensitive = true
}

#Function App API

resource "azurerm_storage_account" "SA-ResumeAPI" {
  name                     = "resumeapi9cbf"
  resource_group_name      = azurerm_resource_group.RG-ResumeAPI.name
  location                 = azurerm_resource_group.RG-ResumeAPI.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "App-Service-Plan" {
  name                = "ASP-ResumeAPIapp-3fff"
  location            = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_function_app" "Function-App" {
  name                = "ResumeAPIapp"
  location            = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
  service_plan_id     = azurerm_service_plan.App-Service-Plan.id

  storage_account_name       = azurerm_storage_account.SA-ResumeAPI.name
  storage_account_access_key = data.azurerm_key_vault_secret.SA-ResumeAPI-AK.value

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
}

resource "azurerm_function_app_function" "Function" {
  name            = "api_trig"
  function_app_id = azurerm_linux_function_app.Function-App.id
  language        = "Python"
  config_json = jsonencode({
    "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": [
        "get",
        "post"
      ]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ],
}