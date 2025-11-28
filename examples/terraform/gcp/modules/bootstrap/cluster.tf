# The `kubernetes_manifest` resource requires an up-and-running
# kubernetes cluster already during the planning phase, because
# it wants to download the kubernetes type definitions.
# So the initial deployment needs to happen in a two-step:
#   1. terraform apply -target=module.bootstrap
#   2. Upload platform images to created registry
#   3. terraform apply


data "google_client_config" "default" {}

# Enable required Google Cloud APIs
resource "google_project_service" "required_apis" {
  # project  = data.google_client_config.default.project
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "monitoring.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "platform_network" {
  name = "tenzir-platform-gke-network"

  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true

  depends_on = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "nodes_subnet" {
  name = "nodes-subnetwork"

  ip_cidr_range = "10.0.0.0/16"
  region        = "europe-west1"

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"

  network = google_compute_network.platform_network.id
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.1.0/24"
  }
}


resource "google_container_cluster" "platform_gke_cluster" {
  name = "tenzir-platform-gke-cluster"

  location                 = "europe-west1"
  enable_autopilot         = true
  enable_l4_ilb_subsetting = true
  deletion_protection = false

  network    = google_compute_network.platform_network.id
  subnetwork = google_compute_subnetwork.nodes_subnet.id

  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = google_compute_subnetwork.nodes_subnet.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.nodes_subnet.secondary_ip_range[1].range_name
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_artifact_registry_repository" "tenzir_platform_repo" {
  location      = "europe-west1"
  repository_id = "tenzir-gke-platform-repo"
  description   = "Docker repository for Tenzir Platform images"
  format        = "DOCKER"
}