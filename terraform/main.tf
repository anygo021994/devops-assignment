locals {
  nodes = {
    cp-1     = { ip = "10.0.1.10", role = "control-plane" }
    worker-1 = { ip = "10.0.1.11", role = "worker" }
    worker-2 = { ip = "10.0.1.12", role = "worker" }
  }

  cp_private_ip = "10.0.1.10"

  nsg_rules = {
    ssh = { port = 22, priority = 100 }
    api = { port = 6443, priority = 110 }
    app = { port = 30080, priority = 120 }
  }
}

resource "random_password" "k3s_token" {
  length  = 40
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-lh-assignment"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-k8s"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-k8s"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Inbound from the internet is limited to the admin IP.
# Traffic inside the VNet is allowed by Azure's default AllowVnetInBound rule.
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-k8s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = local.nsg_rules
    content {
      name                       = "allow-${security_rule.key}-from-admin"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value.port)
      source_address_prefix      = var.allowed_ip_cidr
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "pip" {
  for_each            = local.nodes
  name                = "pip-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  for_each            = local.nodes
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each                        = local.nodes
  name                            = "vm-${each.key}"
  computer_name                   = each.key
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nic[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(
    each.value.role == "control-plane"
    ? templatefile("${path.module}/../scripts/setup-control-plane.sh.tpl", {
      k3s_token = random_password.k3s_token.result
      public_ip = azurerm_public_ip.pip[each.key].ip_address
    })
    : templatefile("${path.module}/../scripts/setup-worker.sh.tpl", {
      k3s_token = random_password.k3s_token.result
      cp_ip     = local.cp_private_ip
    })
  )
}
