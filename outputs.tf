output "load_balancer_ip" {
  description = "Global anycast IP of the HTTPS load balancer"
  value       = google_compute_global_forwarding_rule.default.ip_address
}

output "db_private_ip" {
  description = "Cloud SQL private IP (reachable only inside the VPC)"
  value       = google_sql_database_instance.mysql_instance.private_ip_address
}

output "instance_group_manager" {
  description = "Regional MIG that CI rolls new templates onto"
  value       = google_compute_region_instance_group_manager.grp_manager.name
}

output "vm_kms_key" {
  description = "CMEK used for VM boot disks"
  value       = google_kms_crypto_key.key_vm.id
}
