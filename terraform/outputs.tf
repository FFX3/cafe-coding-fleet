output "controlplane_external_ip" {
  description = "External IP of the Talos control plane node"
  value       = google_compute_instance.talos_controlplane.network_interface[0].access_config[0].nat_ip
}

output "controlplane_internal_ip" {
  description = "Internal IP of the Talos control plane node"
  value       = google_compute_instance.talos_controlplane.network_interface[0].network_ip
}

output "talos_version" {
  description = "Talos version deployed"
  value       = local.talos_version
}

output "data_disk" {
  description = "Data disk name"
  value       = google_compute_disk.data.name
}
