# Uncomment to choose an explicit project and region.
# provider "google" {
#   project = var.project_id
#   region  = var.region
# }

data "google_container_cluster" "platform_gke_cluster" {
  name     = module.bootstrap.cluster_name
  location = module.bootstrap.cluster_location
}

data "google_client_config" "default" {}
