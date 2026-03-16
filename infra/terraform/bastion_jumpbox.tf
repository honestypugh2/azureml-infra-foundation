############################
# Jumpbox Subnet
############################
resource "azurerm_subnet" "snet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.30.2.0/27"]
}

############################
# Bastion Public IP
############################
resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.aml_workspace_name}-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

############################
# Azure Bastion Host
############################
resource "azurerm_bastion_host" "bastion" {
  name                = "${var.aml_workspace_name}-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "bastion-ipcfg"
    subnet_id            = azurerm_subnet.snet_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  tags = var.tags
}