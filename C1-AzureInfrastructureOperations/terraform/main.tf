provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project}"
  location = var.location
}


resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    role = var.role
  }
}


resource "azurerm_subnet" "subnet" {
  name                 = "private_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.project}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "denyFromInternet"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    role = var.role
  }
}


resource "azurerm_subnet_network_security_group_association" "subnetnsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip-${var.project}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" 
  domain_name_label   = "public-ip-${var.project}"
  tags = {
    role = var.role
  }
}


resource "azurerm_lb" "lb" {
  name                = "lb-${var.project}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "lb-${var.project}-ipconfig"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  tags = {
    role = var.role
  }
}


resource "azurerm_lb_backend_address_pool" "lb-be-pool" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "${var.project}-members-pool"
}


resource "azurerm_lb_probe" "lb-probe" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "http-lb-health-probe"
  port                = 80
}


resource "azurerm_lb_rule" "lb-rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http-lb-healthcheck-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-${var.project}-ipconfig"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb-be-pool.id
  probe_id                       = azurerm_lb_probe.lb-probe.id
  idle_timeout_in_minutes        = 30
}


resource "azurerm_network_interface" "nic" {
  count               = var.number-of-vms

  name                = "${var.project}-vif${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "${var.project}-vif${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    role = var.role
  }
}


resource "azurerm_network_interface_backend_address_pool_association" "nic-pool-association" {
  count                   = var.number-of-vms

  network_interface_id    = element(azurerm_network_interface.nic.*.id, count.index)
  ip_configuration_name   = "${var.project}-vif${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-be-pool.id
}


resource "azurerm_availability_set" "avaiset" {
  name                = "availabilityset-${var.project}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  /* 
    The number of Update Domains varies depending on which Azure Region. See documents.
    https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/availability_set
    https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md
  */
  platform_fault_domain_count = 2

  tags = {
    role = var.role
  }
}


resource "azurerm_virtual_machine" "vm" {
  count               = var.number-of-vms

  depends_on          = [azurerm_network_interface.nic, azurerm_availability_set.avaiset]

  name                = "vm-${var.project}-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vm_size             = "Standard_B1s"
  network_interface_ids = [
    element(azurerm_network_interface.nic.*.id, count.index)
  ]
  availability_set_id = azurerm_availability_set.avaiset.id

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile {
    computer_name  = "vm-${var.project}-${count.index}"
    admin_username = "devops"
    admin_password = "devops2021."
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/devops/.ssh/authorized_keys"
    }
  }

  // https://gmusumeci.medium.com/how-to-find-azure-linux-vm-images-for-terraform-or-packer-deployments-24e8e0ac68a
  storage_image_reference  {
    id        = lookup(var.linux-vm-image, "id", null)
    offer     = lookup(var.linux-vm-image, "offer", null)
    publisher = lookup(var.linux-vm-image, "publisher", null)
    sku       = lookup(var.linux-vm-image, "sku", null)
    version   = lookup(var.linux-vm-image, "version", null)
  }

  storage_os_disk {
    name              = "${var.project}-vmbootdisk${count.index}"
    os_type           = "linux"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    role = var.role
  }
}


resource "azurerm_managed_disk" "man-disk" {
  count                = var.number-of-vms

  name                 = "${var.project}-data-vmdisk${count.index}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "10"

  tags = {
    role = var.role
  }
}


resource "azurerm_virtual_machine_data_disk_attachment" "vm-disk-attach" {
  count	             = var.number-of-vms
  managed_disk_id    = azurerm_managed_disk.man-disk.*.id[count.index]

  virtual_machine_id = element(azurerm_virtual_machine.vm.*.id, count.index)
  lun                = "10"
  caching            = "ReadWrite"
}