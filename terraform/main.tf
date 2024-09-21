terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "8ff76be0-453f-470b-a5d2-a270770fd732"
}

terraform {
  backend "azurerm" {
    resource_group_name   = "hub-nva-rg"                # Name of the resource group where the storage account is located
    storage_account_name  = "terrathings01"          # The unique name of your storage account
    container_name        = "resume-tf-state"                # Name of the container created for storing the state file
    key                   = "terraform.tfstate"             
  }
}


data "azurerm_client_config" "current" {}


# Resource Groups

resource "azurerm_resource_group" "RG-ResumeAPI" {
  name     = "resume-api"
  location = "East US"
}

resource "azurerm_resource_group" "RG-Resume" {
  name     = "Resume"
  location = "East US"
}


resource "azurerm_key_vault" "Key-Vault" {
  name                        = "api55237"
  location                    = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name         = azurerm_resource_group.RG-ResumeAPI.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id


    secret_permissions = ["Get", "List"]
  }
}

data "azurerm_key_vault_secret" "SA-ResumeAPI-AK" {
  key_vault_id = azurerm_key_vault.Key-Vault.id  
  name         = "SA-ResumeAPI-AK"
}


# Storage Accounts

resource "azurerm_storage_account" "SA-Resume" {
  name                     = "raineyresume"
  resource_group_name      = azurerm_resource_group.RG-Resume.name
  location                 = azurerm_resource_group.RG-Resume.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  static_website {
    index_document = "index.html"
    error_404_document = "404errorpagehtml.html"
  }
}

resource "azurerm_storage_container" "static_files" {
  name                  = "$web"  
  storage_account_name  = azurerm_storage_account.SA-Resume.name
  container_access_type = "container"
}

resource "azurerm_storage_account" "SA-ResumeAPI" {
  name                     = "resumeapi9cbf"
  resource_group_name      = azurerm_resource_group.RG-ResumeAPI.name
  location                 = azurerm_resource_group.RG-ResumeAPI.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "Service-Plan" {
  name                = "ASP-ResumeAPIapp-3fff"
  location            = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# Function App API


resource "azurerm_linux_function_app" "Function-App" {
  name                = "ResumeAPIapp"
  location            = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
  service_plan_id     = azurerm_service_plan.Service-Plan.id

  storage_account_name       = azurerm_storage_account.SA-ResumeAPI.name
  storage_account_access_key = data.azurerm_key_vault_secret.SA-ResumeAPI-AK.value

  site_config {
    application_stack {
      python_version = "3.10"
    }

    ftps_state = "Disabled"

     cors {
      allowed_origins = [
        "https://APIendpoint.azureedge.net",
        "https://raineyresume.z13.web.core.windows.net",
        "https://resume.rainey-cloud.com",
        "https://CDN-RaineyCloud.azureedge.net",
        "https://APIendpoint.azureedge.net"
      ]
      support_credentials = true
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "https://github.com/JRainey80/ResumeAPIapp/actions/runs/10973026437/artifacts/1961667653"
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "COSMOS_DB_TABLE" = var.db_table
    "DB_Table_Connection_String" = var.db_connection_string
    "SCM_DO_BUILD_DURING_DEPLOYMENT"  = "1"
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
    "ENABLE_ORYX_BUILD"               = "1"
    "PYTHON_VERSION" = "3.10"


  }
}


resource "azurerm_function_app_function" "Function" {
  name            = "api_trig"
  function_app_id = azurerm_linux_function_app.Function-App.id
  language        = "Python"
  config_json = jsonencode({
    "bindings" = [
      {
        "authLevel" = "anonymous"
        "direction" = "in"
        "methods" = [
          "get",
          "post",
        ]
        "name" = "req"
        "type" = "httpTrigger"
      },
      {
        "direction" = "out"
        "name"      = "$return"
        "type"      = "http"
      },
    ]
    "scriptFile" = "function_app.py"
  })
}

# CDN Endpoints


resource "azurerm_cdn_profile" "AZ-CDN-Profile" {
  name                = "AzureCDN"
  location            = azurerm_resource_group.RG-Resume.location
  resource_group_name = azurerm_resource_group.RG-Resume.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "CDN-RaineyCloud" {
  name                = "CDN-RaineyCloud"
  profile_name        = azurerm_cdn_profile.AZ-CDN-Profile.name
  location            = azurerm_resource_group.RG-Resume.location
  resource_group_name = azurerm_resource_group.RG-Resume.name

  origin {
    name      = azurerm_storage_account.SA-Resume.name
    host_name = "raineyresume.z13.web.core.windows.net"
  }
  is_http_allowed  = true
  is_https_allowed = true
}

resource "azurerm_cdn_endpoint_custom_domain" "RaineyCloud-CustomDomain" {
  name            = "resume-rainey-cloud-com"
  cdn_endpoint_id = azurerm_cdn_endpoint.CDN-RaineyCloud.id
  host_name       = "resume.rainey-cloud.com"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}


resource "azurerm_cdn_endpoint" "CDN-API-Endpoint" {
  name                = "APIendpoint"
  profile_name        = azurerm_cdn_profile.AZ-CDN-Profile.name
  location            = azurerm_resource_group.RG-Resume.location
  resource_group_name = azurerm_resource_group.RG-Resume.name

  origin {
    name      = azurerm_linux_function_app.Function-App.name
    host_name = "resumeapiapp.z13.web.core.windows.net"
  }
  is_http_allowed  = false
  is_https_allowed = true
}

# Cosmos DB/Table


resource "azurerm_cosmosdb_account" "DB-Cosmos" {
  name                = "resume-db-1"
  location            = azurerm_resource_group.RG-Resume.location
  resource_group_name = azurerm_resource_group.RG-Resume.name
  offer_type          = "Standard"

    consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

    geo_location {
    location          = "eastus"
    failover_priority = 0  
  }


  capabilities {
    name = "EnableTable"
  }

    capabilities {
    name = "EnableServerless"
  }

}

data "azurerm_cosmosdb_account" "Cosmos-Data" {
  name                = azurerm_cosmosdb_account.DB-Cosmos.name
  resource_group_name = azurerm_cosmosdb_account.DB-Cosmos.resource_group_name
}



resource "azurerm_cosmosdb_table" "DB-Table" {
  name                = "VisitorCounts"
  resource_group_name = azurerm_cosmosdb_account.DB-Cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.DB-Cosmos.name
}


resource "azurerm_user_assigned_identity" "UA-ManagedIdentity" {
  location            = azurerm_resource_group.RG-ResumeAPI.location
  name                = "ResumeAPIapp-id-b604"
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
}