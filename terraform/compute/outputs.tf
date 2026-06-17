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

output "data_disk_device_path" {
  description = "Device path for the data disk (for Talos disk mount config)"
  value       = "/dev/disk/by-id/scsi-0Google_PersistentDisk_${google_compute_instance.talos_controlplane.attached_disk[0].device_name}"
}
