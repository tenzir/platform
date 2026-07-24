output "kubernetes_deployment_names" {
  description = "Names of the created Kubernetes Deployments."
  value = {
    app               = kubernetes_deployment.app_deployment.metadata[0].name
    platform          = kubernetes_deployment.platform_deployment.metadata[0].name
    postgres          = kubernetes_deployment.postgres_deployment.metadata[0].name
    websocket_gateway = kubernetes_deployment.websocket_gateway_deployment.metadata[0].name
  }
}

output "kubernetes_service_names" {
  description = "Names of the created Kubernetes Services."
  value = {
    app               = kubernetes_service.app_service.metadata[0].name
    platform          = kubernetes_service.platform_service.metadata[0].name
    postgres          = kubernetes_service.postgres_service.metadata[0].name
    websocket_gateway = kubernetes_service.websocket_gateway_service.metadata[0].name
  }
}

output "static_ip_address" {
  value = google_compute_global_address.platform_ip.address
  description = "The static IP address reserved for the Ingress."
}


output "oauth_client_id" {
  description = "The OAuth Client ID for the Tenzir Platform IAP."
  value       = google_iap_client.project_client.client_id
}