output "control_plane_public_ip" {
  value = azurerm_public_ip.pip["cp-1"].ip_address
}

output "worker_public_ips" {
  value = { for k, v in azurerm_public_ip.pip : k => v.ip_address if k != "cp-1" }
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/lh_assignment ${var.admin_username}@${azurerm_public_ip.pip["cp-1"].ip_address}"
}

output "app_url" {
  value = "http://${azurerm_public_ip.pip["cp-1"].ip_address}:30080"
}
