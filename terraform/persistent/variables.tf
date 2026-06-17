variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "cafe-coding-fleet"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "northamerica-northeast1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "northamerica-northeast1-a"
}

variable "disk_size_gb" {
  description = "Data disk size in GB (for PostgreSQL, etc.)"
  type        = number
  default     = 20
}
