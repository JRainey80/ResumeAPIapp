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
  subscription_id = var.sub_id
}

terraform {
  backend "azurerm" {
    resource_group_name   = "hub-nva-rg"                
    storage_account_name  = "terrathings01"          
    container_name        = "resume-tf-state"                
    key                   = "terraform.tfstate"             
  }
}


data "azurerm_client_config" "current" {}


# Resource Groups.

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
  name         = var.key_vault_secret
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
  name                = "ASP-resumeapi-af45"
  location            = azurerm_resource_group.RG-ResumeAPI.location
  resource_group_name = azurerm_resource_group.RG-ResumeAPI.name
  os_type             = "Linux"
  sku_name            = "Y1"

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
      python_version = var.python_version
    }
    ip_restriction_default_action = "Allow"
    scm_ip_restriction_default_action = "Allow"
    ftps_state = "Disabled"
    

     cors {
      allowed_origins = [
        "https://APIendpoint.azureedge.net",
        "https://raineyresume.z13.web.core.windows.net",
        "https://resume.rainey-cloud.com",
        "https://CDN-RaineyCloud.azureedge.net",
        "https://api.rainey-cloud.com",
        "https://portal.azure.com"
      ]
      support_credentials = false
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = var.run_from_package
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "COSMOS_DB_TABLE" = var.db_table
    "DB_Table_Connection_String" = var.db_connection_string
    "SCM_DO_BUILD_DURING_DEPLOYMENT"  = "1"
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
    "ENABLE_ORYX_BUILD"               = "1"
    "PYTHON_VERSION" = var.python_version
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"

  }

    lifecycle {
      ignore_changes = [app_settings["FUNCTIONS_EXTENSION_VERSION"]]
    }
}


resource "azurerm_function_app_function" "Function" {
  name            = "api_trig"
  function_app_id = azurerm_linux_function_app.Function-App.id
  language        = "Python"
  config_json = jsonencode({
   "bindings" = [
      {
        "authLevel" = "anonymous",
        "direction" = "in",
        "methods" = [
          "get",
          "post"
        ]
        "name" = "req",
        "type" = "httpTrigger"
      },
      {
       "direction" = "out",
        "name"      = "$return",
        "type"      = "http"
      }
    ],
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
          host_name  = "raineyresume.z13.web.core.windows.net"
          http_port  = 80
          https_port = 443
          name       = "raineyresume-z13-web-core-windows-net"
        } 
  is_http_allowed  = true
  is_https_allowed = true
  is_compression_enabled = true
  querystring_caching_behaviour = "IgnoreQueryString"
  optimization_type = "GeneralWebDelivery"
  origin_path = null
  content_types_to_compress = [
    "application/eot",
    "application/font",
    "application/font-sfnt",
    "application/javascript",
    "application/json",
    "application/opentype",
    "application/otf",
    "application/pkcs7-mime",
    "application/truetype",
    "application/ttf",
    "application/vnd.ms-fontobject",
    "application/xhtml+xml",
    "application/xml",
    "application/xml+rss",
    "application/x-font-opentype",
    "application/x-font-truetype",
    "application/x-font-ttf",
    "application/x-httpd-cgi",
    "application/x-javascript",
    "application/x-mpegurl",
    "application/x-opentype",
    "application/x-otf",
    "application/x-perl",
    "application/x-ttf",
    "font/eot",
    "font/ttf",
    "font/otf",
    "font/opentype",
    "image/svg+xml",
    "text/css",
    "text/csv",
    "text/html",
    "text/javascript",
    "text/js",
    "text/plain",
    "text/richtext",
    "text/tab-separated-values",
    "text/xml",
    "text/x-script",
    "text/x-component",
    "text/x-java-source"
  ]

  lifecycle {
    ignore_changes = [
      content_types_to_compress,
      is_compression_enabled,
      origin_host_header
    ]
  }
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
  lifecycle {
    ignore_changes = [
      cdn_endpoint_id 
    ]
  }
}


resource "azurerm_cdn_endpoint" "CDN-API-Endpoint" {
  name                = "APIendpoint"
  profile_name        = azurerm_cdn_profile.AZ-CDN-Profile.name
  location            = azurerm_resource_group.RG-Resume.location
  resource_group_name = azurerm_resource_group.RG-Resume.name

  origin { 
        host_name  = "resumeapiapp.azurewebsites.net"
        http_port  = 80
        https_port = 443
        name       = "resumeapiapp-azurewebsites-net"
        }
  is_http_allowed  = true
  is_https_allowed = true
  is_compression_enabled = true
  querystring_caching_behaviour = "IgnoreQueryString"
  optimization_type = "GeneralWebDelivery"
  origin_path = null
  probe_path  = null
  content_types_to_compress = [
    "application/eot",
    "application/font",
    "application/font-sfnt",
    "application/javascript",
    "application/json",
    "application/opentype",
    "application/otf",
    "application/pkcs7-mime",
    "application/truetype",
    "application/ttf",
    "application/vnd.ms-fontobject",
    "application/xhtml+xml",
    "application/xml",
    "application/xml+rss",
    "application/x-font-opentype",
    "application/x-font-truetype",
    "application/x-font-ttf",
    "application/x-httpd-cgi",
    "application/x-javascript",
    "application/x-mpegurl",
    "application/x-opentype",
    "application/x-otf",
    "application/x-perl",
    "application/x-ttf",
    "font/eot",
    "font/ttf",
    "font/otf",
    "font/opentype",
    "image/svg+xml",
    "text/css",
    "text/csv",
    "text/html",
    "text/javascript",
    "text/js",
    "text/plain",
    "text/richtext",
    "text/tab-separated-values",
    "text/xml",
    "text/x-script",
    "text/x-component",
    "text/x-java-source"
  ]

  lifecycle {
    ignore_changes = [
      content_types_to_compress,
      is_compression_enabled,
      origin_host_header
      
    ]
  }
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

