# Define default variable

variable "location" { default = "" }
variable "project" { default = "" }
variable "imagevhd" { default = "" }

# Configure the Microsoft Azure Provider

provider "azurerm" {
  # This will default to using $ARM_SUBSCRIPTION_ID , $ARM_CLIENT_ID , $ARM_CLIENT_SECRET , $ARM_TENANT_ID
}

# Create a random number for this platform
resource "random_id" "environment" {
  prefix = "${var.project}"
  byte_length = 0
}

##############################################################################
# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "${var.project}"
  location = "${var.location}"
  tags {
    environment = "${var.project}"
  }
  lifecycle {
    prevent_destroy       = true
  }

}

# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "network" {
  name                = "${format("network_%s", var.project)}"
  address_space       = ["192.168.168.0/24"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
  }
}

resource "azurerm_subnet" "subnet" {
  name           = "${format("subnet_%s", var.project)}"
  address_prefix = "192.168.168.0/24"
  resource_group_name = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.network.name}"
  lifecycle {
    create_before_destroy = false
    prevent_destroy       = false
  }
}
