# -- VPC outputs

output "network_id" {
    description = "The network id of the VPC"
    value = google_compute_network.platform_network.id
}

# -- Cluster outputs

output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.platform_gke_cluster.name
}

output "cluster_location" {
  description = "The location of the GKE cluster."
  value       = google_container_cluster.platform_gke_cluster.location
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster."
  value       = google_container_cluster.platform_gke_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster."
  value       = google_container_cluster.platform_gke_cluster.master_auth[0].cluster_ca_certificate
}

# -- Artifact Registry outputs

output "registry_id" {
    description = "The registry id of the Artifact Registry"
    value = google_artifact_registry_repository.tenzir_platform_repo.repository_id    
}

output "registry_baseurl" {
    description = "The base url for images in this registry"
    value = "${google_artifact_registry_repository.tenzir_platform_repo.location}-docker.pkg.dev/${data.google_client_config.default.project}/${google_artifact_registry_repository.tenzir_platform_repo.repository_id}"
}