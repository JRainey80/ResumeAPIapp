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

resource "azurerm_resource_group" "RG-Resume" {
  name     = "Resume"
  location = "East US"
}