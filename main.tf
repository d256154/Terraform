# Configure the Microsoft Azure Provider
terraform {
required_providers {
azurerm = {
source  = "hashicorp/azurerm"
version = "=2.46.0"
}
}
}

provider "azurerm" {
features {}
subscription_id = "2a398193-e726-4126-8472-dd1e313dd213"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "West us2"

}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "West us2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.4.0/24"]
}

# Create subnet 2
resource "azurerm_subnet" "myterraformsubnet2" {
    name                 = "mySubnet2"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.5.0/24"]
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "West us2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges     = [22, 8080]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "myterraformnsg2" {
    name                = "myNetworkSecurityGroup2"
    location            = "West us2"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = [22, 5432]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    count = 2
    name                      = "myNIC-${count.index}"
    location                  = "West us2"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        #public_ip_address_id         = azurerm_public_ip.myterraformpublicip.id
    }

}

# Create network interface2
resource "azurerm_network_interface" "myterraformnic2" {
    count = 2
    name                      = "myNIC2-${count.index}"
    location                  = "West us2"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet2.id
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_subnet_network_security_group_association" "connectSGtoSUB2" {
  subnet_id                 = azurerm_subnet.myterraformsubnet2.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg2.id
}

resource "azurerm_subnet_network_security_group_association" "connectSGtoSUB" {
  subnet_id                 = azurerm_subnet.myterraformsubnet.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "West us2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform"
    }
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    count = 2
    name                     = "dbsrv-${count.index}"
    location                 = "West us2"
    resource_group_name      = azurerm_resource_group.myterraformgroup.name
    #network_interface_ids    = [azurerm_network_interface.myterraformnic2.id]
    size                     = "Standard_DS1_v2"
    network_interface_ids = [
        azurerm_network_interface.myterraformnic2.*.id[count.index],
      ]
    os_disk {
        name                 = "myOsDisk"
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "dbsrv"
    admin_username = "?"
    disable_password_authentication = false
    admin_password     = "?"

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

}

# Create virtual machine2
resource "azurerm_windows_virtual_machine" "myterraformvm2" {
  count = 2
  name                  = "WEBSRV-${count.index}"
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  location              = "West us2"
  size                  = "Standard_F2"
  admin_username        = "?"
  admin_password        = "?"
  #network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  network_interface_ids = [
      azurerm_network_interface.myterraformnic.*.id[count.index],
    ]
  #disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# Create public IPs LB
resource "azurerm_public_ip" "PubIP" {
    name                         = "PublicIPforLB"
    location                     = "West us2"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Static"
}

# Configure the loadBalancer
resource "azurerm_lb" "FrontLB" {
  name                = "LoadBalancerFront"
  location            = "West us2"
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  frontend_ip_configuration {
    name                 = "PublicIPforLB"
    public_ip_address_id = azurerm_public_ip.PubIP.id
  }
}

# Configure backend adress pull for loadBalancer
resource "azurerm_lb_backend_address_pool" "pool" {
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id = azurerm_lb.FrontLB.id
  name            = "FrontEndAddressPool"
}

resource "azurerm_lb_probe" "azurerm_lb_probe" {
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.FrontLB.id
  name                = "http-running-probe"
  port                = 8080
}

# Associating the network interface to the loadBalancer backend adress pull

resource "azurerm_network_interface_backend_address_pool_association" "association" {
  count = 2
    network_interface_id    = element(azurerm_network_interface.myterraformnic.*.id, count.index)
    ip_configuration_name   = "external"
    backend_address_pool_id = element(azurerm_lb_backend_address_pool.pool.*.id, count.index)
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = azurerm_resource_group.myterraformgroup.name
  loadbalancer_id                = azurerm_lb.FrontLB.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPforLB"
  probe_id = azurerm_lb_probe.azurerm_lb_probe.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}
