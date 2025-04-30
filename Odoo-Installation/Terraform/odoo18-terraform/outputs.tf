
output "vm_public_ip" {
  value = google_compute_instance.odoo_vm.network_interface[0].access_config[0].nat_ip
}

output "db_instance_connection_name" {
  value = google_sql_database_instance.odoo_db_instance.connection_name
}
