
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "load_balancer_name" {
  value = azurerm_lb.lb.name
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_ip.ip_address
}

output "application_url" {
  value = "http://${azurerm_public_ip.lb_ip.ip_address}"
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "initial_vm_instances" {
  value = azurerm_linux_virtual_machine_scale_set.vmss.instances
}

output "autoscale_resource_id" {
  value = azurerm_monitor_autoscale_setting.autoscale.target_resource_id
}

output "backend_pool_name" {
  value = azurerm_lb_backend_address_pool.backend.name
}
