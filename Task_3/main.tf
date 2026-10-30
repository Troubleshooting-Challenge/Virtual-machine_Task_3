
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ------------------------------------------------
# 1. RESOURCE GROUP
# ------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "student-rg-task3"
  location = var.location
}

# ------------------------------------------------
# 2. VIRTUAL NETWORK
# ------------------------------------------------

resource "azurerm_virtual_network" "vnet" {
  name                = "student-vnet-task3"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# ------------------------------------------------
# 3. SUBNET
# ------------------------------------------------

resource "azurerm_subnet" "subnet" {
  name                 = "student-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ------------------------------------------------
# 4. NETWORK SECURITY GROUP
# ------------------------------------------------

resource "azurerm_network_security_group" "nsg" {
  name                = "student-nsg-task3"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH from student's public IP
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ssh_cidr
    destination_address_prefix = "*"
  }

  # Allow HTTP traffic
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------
# 5. NSG ASSOCIATION WITH SUBNET
# ------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ------------------------------------------------
# 6. LOAD BALANCER PUBLIC IP
# ------------------------------------------------

resource "azurerm_public_ip" "lb_ip" {
  name                = "student-lb-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

# ------------------------------------------------
# 7. AZURE LOAD BALANCER
# ------------------------------------------------

resource "azurerm_lb" "lb" {
  name                = "student-load-balancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}

# ------------------------------------------------
# 8. LOAD BALANCER BACKEND POOL
# ------------------------------------------------

resource "azurerm_lb_backend_address_pool" "backend" {
  name            = "student-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

# ------------------------------------------------
# 9. HEALTH PROBE
# ------------------------------------------------

resource "azurerm_lb_probe" "probe" {
  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# ------------------------------------------------
# 10. LOAD BALANCER RULE
# ------------------------------------------------

resource "azurerm_lb_rule" "rule" {
  name                           = "http-load-balancer-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.backend.id
  ]

  probe_id = azurerm_lb_probe.probe.id

  disable_outbound_snat = true
}

# ------------------------------------------------
# 11. LOAD BALANCER OUTBOUND RULE
# Allows VMSS instances to access the internet
# for package installation and updates.
# ------------------------------------------------

resource "azurerm_lb_outbound_rule" "outbound" {
  name                    = "vmss-outbound-rule"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id
  allocated_outbound_ports = 1024
  idle_timeout_in_minutes = 15
  enable_tcp_reset        = true

  frontend_ip_configuration {
    name = "LoadBalancerFrontEnd"
  }
}

# ------------------------------------------------
# 12. LINUX VIRTUAL MACHINE SCALE SET
# Starts with TWO Ubuntu VM instances.
# ------------------------------------------------

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "student-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku       = var.vm_size
  instances = 2

  admin_username                  = var.admin_username
  disable_password_authentication = true

  upgrade_mode = "Automatic"

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Install NGINX on every VMSS instance
  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - nginx

    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
      - bash -c "echo '<h1>NGINX Application - VMSS Instance</h1>' > /var/www/html/index.html"
  EOF
  )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet.id

      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.backend.id
      ]
    }
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.nsg_assoc,
    azurerm_lb_rule.rule,
    azurerm_lb_outbound_rule.outbound
  ]
}

# ------------------------------------------------
# 13. AZURE MONITOR AUTOSCALE
# Target must be VM SCALE SET ID.
# ------------------------------------------------

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "student-vmss-autoscale"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  target_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "cpu-autoscale-profile"

    capacity {
      minimum = "2"
      maximum = "3"
      default = "2"
    }

    # SCALE OUT: CPU greater than 80%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"

        operator         = "GreaterThan"
        threshold        = 80
        time_grain       = "PT1M"
        statistic        = "Average"
        time_window      = "PT5M"
        time_aggregation = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # SCALE IN: CPU less than 30%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"

        operator         = "LessThan"
        threshold        = 30
        time_grain       = "PT1M"
        statistic        = "Average"
        time_window      = "PT10M"
        time_aggregation = "Average"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
